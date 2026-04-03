package com.jl803.mediaplay

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val pipChannel = "mediaplay/pip"
    private var autoPipEnabled = false
    private var pipAspectRatio = Rational(16, 9)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPictureInPicture" -> {
                        result.success(enterPictureInPictureFromFlutter(call.argument<Int>("aspectRatioWidth"), call.argument<Int>("aspectRatioHeight")))
                    }
                    "updateAutoPipState" -> {
                        updateAutoPipState(call.argument<Boolean>("enabled"), call.argument<Int>("aspectRatioWidth"), call.argument<Int>("aspectRatioHeight"))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()

        // Android 12+ handles auto-entry via PictureInPictureParams.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return
        }

        if (autoPipEnabled && !isChangingConfigurations && !isInPictureInPictureModeCompat()) {
            enterPictureInPictureMode(
                PictureInPictureParams.Builder()
                    .setAspectRatio(pipAspectRatio)
                    .build()
            )
        }
    }

    private fun enterPictureInPictureFromFlutter(width: Int?, height: Int?): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }

        val safeWidth = if ((width ?: 0) > 0) width!! else 16
        val safeHeight = if ((height ?: 0) > 0) height!! else 9
        pipAspectRatio = Rational(safeWidth, safeHeight)

        val params = PictureInPictureParams.Builder()
            .setAspectRatio(pipAspectRatio)
            .build()

        enterPictureInPictureMode(params)
        return true
    }

    private fun updateAutoPipState(enabled: Boolean?, width: Int?, height: Int?) {
        autoPipEnabled = enabled == true

        val safeWidth = if ((width ?: 0) > 0) width!! else 16
        val safeHeight = if ((height ?: 0) > 0) height!! else 9
        pipAspectRatio = Rational(safeWidth, safeHeight)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val paramsBuilder = PictureInPictureParams.Builder()
                .setAspectRatio(pipAspectRatio)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                paramsBuilder.setAutoEnterEnabled(autoPipEnabled)
            }

            setPictureInPictureParams(paramsBuilder.build())
        }
    }

    private fun isInPictureInPictureModeCompat(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInPictureInPictureMode
    }
}
