package kz.xatbox.xatbox_mobile

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity (required by local_auth's BiometricPrompt).
 *
 * `xatbox/pip` channel for Picture-in-Picture during video calls:
 *  * `isSupported` → Boolean
 *  * `enter` → Boolean (false when the system refuses, e.g. not resumed)
 *  * `setAutoEnter {enabled}` → enter PiP by itself when the user leaves the
 *    app (Android 12+ auto-enter, Android 8–11 onUserLeaveHint)
 *  * callback `pipChanged(Boolean)` when the PiP mode changes.
 */
class MainActivity : FlutterFragmentActivity() {
    private var pipChannel: MethodChannel? = null
    private var windowChannel: MethodChannel? = null
    private var installerChannel: MethodChannel? = null
    private var autoEnterPip = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(pipSupported())
                    "enter" -> result.success(enterPip())
                    "setAutoEnter" -> {
                        autoEnterPip = call.argument<Boolean>("enabled") == true
                        applyAutoEnter()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        windowChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WINDOW_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    // Settings «Скрывать содержимое»: blank app switcher preview, no screenshots.
                    "setSecure" -> {
                        if (call.arguments == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        installerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "canRequestInstalls" -> result.success(canRequestInstalls())
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(null)
                    }
                    "install" -> result.success(installApk(call.argument<String>("path")))
                    else -> result.notImplemented()
                }
            }
        }
    }

    // ---- in-app updates (lib/features/update) --------------------------------------------

    private fun canRequestInstalls(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    /** «Install unknown apps» page for this app (Android 8+). */
    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            startActivity(
                android.content.Intent(
                    android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    android.net.Uri.parse("package:$packageName"),
                ),
            )
        } catch (e: android.content.ActivityNotFoundException) {
            startActivity(android.content.Intent(android.provider.Settings.ACTION_SECURITY_SETTINGS))
        }
    }

    /** "started" | "needs_permission" | "failed". Only files under cache/updates. */
    private fun installApk(path: String?): String {
        if (path == null) return "failed"
        if (!canRequestInstalls()) return "needs_permission"
        return try {
            val file = java.io.File(path).canonicalFile
            val updates = java.io.File(cacheDir, "updates").canonicalFile
            if (!file.isFile || file.parentFile != updates) return "failed"
            val uri = androidx.core.content.FileProvider.getUriForFile(this, "$packageName.updates", file)
            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            "started"
        } catch (e: Exception) {
            "failed"
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        installerChannel?.setMethodCallHandler(null)
        installerChannel = null
        pipChannel?.setMethodCallHandler(null)
        pipChannel = null
        windowChannel?.setMethodCallHandler(null)
        windowChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun pipSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun pipParams(): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val builder = PictureInPictureParams.Builder().setAspectRatio(Rational(9, 16))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoEnterPip)
        }
        return builder.build()
    }

    private fun applyAutoEnter() {
        if (!pipSupported()) return
        try {
            pipParams()?.let { setPictureInPictureParams(it) }
        } catch (e: IllegalStateException) {
            // Activity not in a state that accepts PiP params; ignored.
        }
    }

    private fun enterPip(): Boolean {
        if (!pipSupported()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInPictureInPictureMode) return true
        return try {
            val params = pipParams() ?: return false
            enterPictureInPictureMode(params)
        } catch (e: IllegalStateException) {
            false
        } catch (e: IllegalArgumentException) {
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Android 12+ enters by itself through setAutoEnterEnabled.
        if (autoEnterPip && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) enterPip()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("pipChanged", isInPictureInPictureMode)
    }

    private companion object {
        const val PIP_CHANNEL = "xatbox/pip"
        const val WINDOW_CHANNEL = "xatbox/window"
        /** In-app updates: `canRequestInstalls`, `openInstallSettings`, `install {path}`. */
        const val INSTALLER_CHANNEL = "xatbox/installer"
    }
}
