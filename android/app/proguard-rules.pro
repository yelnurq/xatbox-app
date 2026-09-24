# XatBox release shrinking (R8 full mode, AGP 9). Plugins that ship their
# own consumer rules (flutter_webrtc: org.webrtc.**, flutter_callkit_incoming:
# com.hiennv.** + Jackson, Firebase, Gson, media3) are not repeated here.
# Everything below is reached through reflection, JNI or persisted JSON.

# ---- flutter_local_notifications ------------------------------------------
# Scheduled notifications are stored as Gson JSON in SharedPreferences and
# read back by ScheduledNotificationBootReceiver after a reboot or an app
# update. Field names must stay stable across builds (a renamed field would
# drop every pending reminder after the update), and the
# TypeToken<ArrayList<NotificationDetails>> needs its generic signature.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken

# ---- WebRTC / LiveKit -------------------------------------------------------
# Native code calls back into Java by name (JNI). flutter_webrtc's consumer
# rules keep org.webrtc.**; its own plugin classes are also called from JNI.
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn org.webrtc.**

# ---- flutter_background (screen sharing foreground service) --------------
-keep class de.julianassmann.flutter_background.** { *; }

# ---- home_widget: provider class looked up by name (Class.forName) --------
-keep class es.antonborri.home_widget.** { *; }
-keep class kz.xatbox.xatbox_mobile.XatBoxWidgetProvider { *; }

# ---- receive_sharing_intent / audio / video -------------------------------
-keep class com.kasem.receive_sharing_intent.** { *; }
-keep class com.ryanheise.** { *; }

# ---- record: encoder selected at runtime ----------------------------------
-keep class com.llfbandit.record.** { *; }
