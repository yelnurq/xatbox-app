package kz.xatbox.xatbox_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

/**
 * «XatBox» home screen widget: unread chats (count + top 3) and the next
 * calendar event today.
 *
 * Data comes only from the app: lib/features/home_widget writes one JSON
 * snapshot under [DATA_KEY] into home_widget's SharedPreferences and requests
 * an update when it changes (throttled). Nothing is fetched here. The system
 * redraws every 30 minutes (updatePeriodMillis), which drops events that are
 * over and the whole event list after the day it was written for.
 *
 * Snapshot (v1):
 * {"v":1,"signedIn":true,"hidden":false,"unread":5,"accent":"#1A73E8",
 *  "headline":"5 непрочитанных","dayEnd":<ms>,
 *  "chats":[{"id","title","initial","preview"?,"unread","color"}],
 *  "events":[{"title","time","start":<ms>,"end":<ms>}],
 *  "labels":{"signIn","noEvents"}}
 *
 * Without a snapshot (never signed in, signed out) the widget only asks to
 * sign in. Taps open `xatbox://` links, which the app routes after its
 * sign-in and lock checks (app_links → DeepLinks).
 */
class XatBoxWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val snapshot = parse(widgetData.getString(DATA_KEY, null))
        val now = System.currentTimeMillis()
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, render(context, snapshot, now))
        }
    }

    private fun render(context: Context, s: JSONObject?, now: Long): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.xatbox_widget)
        views.removeAllViews(R.id.widget_rows)
        val labels = s?.optJSONObject("labels")
        fun label(key: String, fallback: Int): String =
            labels?.optString(key).takeUnless { it.isNullOrEmpty() } ?: context.getString(fallback)

        views.setOnClickPendingIntent(R.id.widget_header, open(context, "xatbox://chat", REQ_HEADER))
        views.setOnClickPendingIntent(R.id.widget_root, open(context, "xatbox://chat", REQ_ROOT))

        if (s == null || !s.optBoolean("signedIn")) {
            views.setTextViewText(R.id.widget_headline, label("signIn", R.string.widget_sign_in))
            views.setTextColor(R.id.widget_headline, context.getColor(R.color.widget_text_secondary))
            views.setViewVisibility(R.id.widget_rows, View.GONE)
            views.setViewVisibility(R.id.widget_event, View.GONE)
            views.setViewVisibility(R.id.widget_divider, View.GONE)
            return views
        }

        val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val accent = color(
            s.optString(if (night) "accentDark" else "accent"),
            context.getColor(R.color.widget_accent),
        )
        val unread = s.optInt("unread")
        views.setTextViewText(
            R.id.widget_headline,
            s.optString("headline").ifEmpty { context.getString(R.string.widget_no_unread) },
        )
        views.setTextColor(
            R.id.widget_headline,
            if (unread > 0) accent else context.getColor(R.color.widget_text_secondary),
        )
        views.setInt(R.id.widget_logo, "setColorFilter", accent)

        // Chats: hidden when the app hides content (PIN lock, «Скрывать содержимое»).
        val chats = if (s.optBoolean("hidden")) JSONArray() else s.optJSONArray("chats") ?: JSONArray()
        val shown = minOf(chats.length(), MAX_CHATS)
        views.setViewVisibility(R.id.widget_rows, if (shown > 0) View.VISIBLE else View.GONE)
        for (i in 0 until shown) {
            val chat = chats.optJSONObject(i) ?: continue
            views.addView(R.id.widget_rows, chatRow(context, chat, accent, i))
        }

        // Next event today (still running or upcoming); not shown at all
        // while the app hides content.
        if (s.optBoolean("hidden")) {
            views.setViewVisibility(R.id.widget_divider, View.GONE)
            views.setViewVisibility(R.id.widget_event, View.GONE)
            return views
        }
        views.setViewVisibility(R.id.widget_divider, View.VISIBLE)
        views.setViewVisibility(R.id.widget_event, View.VISIBLE)
        views.setInt(R.id.widget_event_icon, "setColorFilter", accent)
        val next = nextEvent(s, now)
        if (next != null) {
            views.setTextViewText(R.id.widget_event_title, next.optString("title"))
            views.setTextViewText(R.id.widget_event_time, next.optString("time"))
            views.setViewVisibility(R.id.widget_event_time, View.VISIBLE)
            views.setTextColor(R.id.widget_event_title, context.getColor(R.color.widget_text))
        } else {
            views.setTextViewText(R.id.widget_event_title, label("noEvents", R.string.widget_no_events))
            views.setViewVisibility(R.id.widget_event_time, View.GONE)
            views.setTextColor(R.id.widget_event_title, context.getColor(R.color.widget_text_secondary))
        }
        views.setOnClickPendingIntent(R.id.widget_event, open(context, "xatbox://calendar", REQ_EVENT))
        return views
    }

    private fun chatRow(context: Context, chat: JSONObject, accent: Int, index: Int): RemoteViews {
        val row = RemoteViews(context.packageName, R.layout.xatbox_widget_row)
        row.setTextViewText(R.id.row_initial, chat.optString("initial").ifEmpty { "•" })
        row.setInt(R.id.row_avatar, "setColorFilter", color(chat.optString("color"), accent))
        row.setTextViewText(R.id.row_title, chat.optString("title"))
        val preview = chat.optString("preview")
        if (preview.isNotEmpty()) {
            row.setTextViewText(R.id.row_preview, preview)
            row.setViewVisibility(R.id.row_preview, View.VISIBLE)
        } else {
            row.setViewVisibility(R.id.row_preview, View.GONE)
        }
        val count = chat.optInt("unread")
        if (count > 0) {
            row.setTextViewText(R.id.row_unread, if (count > 99) "99+" else count.toString())
            row.setInt(R.id.row_unread_bg, "setColorFilter", accent)
            row.setViewVisibility(R.id.row_unread_box, View.VISIBLE)
        } else {
            row.setViewVisibility(R.id.row_unread_box, View.GONE)
        }
        val id = chat.optString("id")
        if (id.isNotEmpty()) {
            row.setOnClickPendingIntent(
                R.id.row_root,
                open(context, "xatbox://chat/" + Uri.encode(id), REQ_CHAT + index),
            )
        }
        return row
    }

    companion object {
        /** Key written by lib/features/home_widget/home_widget_service.dart. */
        const val DATA_KEY = "xatbox.widget"
        private const val MAX_CHATS = 3
        private const val REQ_ROOT = 7100
        private const val REQ_HEADER = 7101
        private const val REQ_EVENT = 7102
        private const val REQ_CHAT = 7110

        fun parse(raw: String?): JSONObject? =
            if (raw.isNullOrEmpty()) null else try {
                JSONObject(raw)
            } catch (e: Exception) {
                null
            }

        /** First event of the snapshot's day that has not ended yet. */
        fun nextEvent(s: JSONObject, now: Long): JSONObject? {
            val dayEnd = s.optLong("dayEnd", 0L)
            if (dayEnd in 1..now) return null
            val events = s.optJSONArray("events") ?: return null
            for (i in 0 until events.length()) {
                val e = events.optJSONObject(i) ?: continue
                if (e.optLong("end", 0L) > now) return e
            }
            return null
        }

        private fun color(value: String?, fallback: Int): Int =
            if (value.isNullOrEmpty()) fallback else try {
                Color.parseColor(value)
            } catch (e: IllegalArgumentException) {
                fallback
            }

        private fun open(context: Context, link: String, requestCode: Int): PendingIntent {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(link), context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            return PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
