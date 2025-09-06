package com.example.cb_file_manager

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.util.Rational
import android.app.PictureInPictureParams
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import com.coolbird.cb_file_manager.MemoryManagementPlugin

// Media3 / ExoPlayer for native PiP playback
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout

class MainActivity : FlutterActivity() {
    private val CHANNEL = "cb_file_manager/external_apps"
    private val PIP_CHANNEL = "cb_file_manager/pip"
    private lateinit var pipChannel: MethodChannel

    // Native PiP player (Media3 ExoPlayer)
    private var pipPlayer: ExoPlayer? = null
    private var pipPlayerView: PlayerView? = null
    private var pipPrepared: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register MemoryManagementPlugin
        flutterEngine.plugins.add(MemoryManagementPlugin())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledAppsForFile" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val extension = call.argument<String>("extension") ?: ""
                    result.success(getInstalledAppsForFile(filePath, extension))
                }
                "openFileWithApp" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val packageName = call.argument<String>("packageName") ?: ""
                    result.success(openFileWithApp(filePath, packageName))
                }
                "openWithSystemChooser" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    result.success(openWithSystemChooser(filePath))
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Picture-in-Picture channel for Android
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    try {
                        val width = (call.argument<Int>("width") ?: 16).coerceAtLeast(1)
                        val height = (call.argument<Int>("height") ?: 9).coerceAtLeast(1)

                        // Optional: source info to prepare native player
                        val sourceType = call.argument<String>("sourceType")
                        val source = call.argument<String>("source")
                        val positionMs = call.argument<Int>("positionMs")
                        val playing = call.argument<Boolean>("playing") ?: true
                        val volume = call.argument<Double>("volume")?.toFloat()

                        if (source != null && source.isNotEmpty()) {
                            try {
                                prepareNativePip(sourceType ?: "file", source, positionMs, playing, volume)
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }
                        enterPipModeSafe(width, height)
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("PIP_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode)
        // Toggle native overlay visibility and notify Flutter
        showNativePipView(isInPictureInPictureMode)
        try {
            if (this::pipChannel.isInitialized) {
                val payload: MutableMap<String, Any> = HashMap()
                payload["inPip"] = isInPictureInPictureMode
                pipPlayer?.let { p ->
                    try {
                        payload["positionMs"] = p.currentPosition.toInt()
                        payload["playing"] = p.isPlaying
                        payload["volume"] = p.volume.toDouble()
                    } catch (_: Throwable) {}
                }
                pipChannel.invokeMethod("onPipChanged", payload)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        showNativePipView(isInPictureInPictureMode)
        try {
            if (this::pipChannel.isInitialized) {
                val payload: MutableMap<String, Any> = HashMap()
                payload["inPip"] = isInPictureInPictureMode
                pipPlayer?.let { p ->
                    try {
                        payload["positionMs"] = p.currentPosition.toInt()
                        payload["playing"] = p.isPlaying
                        payload["volume"] = p.volume.toDouble()
                    } catch (_: Throwable) {}
                }
                pipChannel.invokeMethod("onPipChanged", payload)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun enterPipModeSafe(width: Int, height: Int) {
        try {
            // Check if PiP is supported
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                throw Exception("PiP requires Android 8.0 (API 26) or higher")
            }

            // Check if PiP is enabled in system settings
            if (!packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
                throw Exception("PiP is not supported on this device")
            }

            // Validate dimensions
            val validWidth = width.coerceAtLeast(1).coerceAtMost(10000)
            val validHeight = height.coerceAtLeast(1).coerceAtMost(10000)
            
            val ratio = Rational(validWidth, validHeight)
            val builder = PictureInPictureParams.Builder()
                .setAspectRatio(ratio)
            
            // Enable seamless resize on Android 12+ (API 31+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try { 
                    builder.setSeamlessResizeEnabled(true) 
                } catch (_: Throwable) {
                    // Ignore if not supported
                }
            }
            
            val params = builder.build()

            // Show native player view above Flutter content while in PiP
            showNativePipView(true)
            enterPictureInPictureMode(params)
            
        } catch (e: Exception) {
            e.printStackTrace()
            // Log the error for debugging
            android.util.Log.e("MainActivity", "PiP error: ${e.message}", e)
            throw e
        }
    }

    private fun ensureNativePipComponents() {
        if (pipPlayer == null) {
            pipPlayer = ExoPlayer.Builder(this).build()
        }
        if (pipPlayerView == null) {
            pipPlayerView = PlayerView(this).apply {
                useController = false
                player = pipPlayer
                layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
                visibility = View.GONE
            }
            addContentView(pipPlayerView, pipPlayerView!!.layoutParams)
        }
    }

    private fun showNativePipView(visible: Boolean) {
        ensureNativePipComponents()
        pipPlayerView?.visibility = if (visible) View.VISIBLE else View.GONE
        if (!visible) {
            // Pause when leaving PiP
            try { pipPlayer?.playWhenReady = false } catch (_: Throwable) {}
        }
    }

    private fun prepareNativePip(type: String, source: String, positionMs: Int?, play: Boolean, volume: Float?) {
        ensureNativePipComponents()
        val uri: Uri = if (type == "file") {
            val f = File(source)
            Uri.fromFile(f)
        } else {
            Uri.parse(source)
        }
        pipPlayer?.setMediaItem(MediaItem.fromUri(uri))
        pipPlayer?.prepare()
        if (positionMs != null && positionMs > 0) {
            try { pipPlayer?.seekTo(positionMs.toLong()) } catch (_: Throwable) {}
        }
        if (volume != null) {
            try { pipPlayer?.volume = volume.coerceIn(0f, 1f) } catch (_: Throwable) {}
        }
        pipPlayer?.playWhenReady = play
    }

    private fun getInstalledAppsForFile(filePath: String, extension: String): List<Map<String, Any>> {
        val file = File(filePath)
        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.provider",
            file
        )

        val intent = Intent(Intent.ACTION_VIEW)
        intent.setDataAndType(uri, getMimeType(extension))
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        
        val packageManager = packageManager
        val resolveInfos = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
        
        return resolveInfos.map { resolveInfo ->
            val appName = resolveInfo.loadLabel(packageManager).toString()
            val packageName = resolveInfo.activityInfo.packageName
            val icon = resolveInfo.loadIcon(packageManager)
            
            mapOf(
                "appName" to appName,
                "packageName" to packageName,
                "iconBytes" to drawableToByteArray(icon)
            )
        }
    }

    private fun openFileWithApp(filePath: String, packageName: String): Boolean {
        try {
            val file = File(filePath)
            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.provider",
                file
            )

            val intent = Intent(Intent.ACTION_VIEW)
            intent.setDataAndType(uri, getMimeType(filePath.split(".").last()))
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            
            if (packageName.isNotEmpty()) {
                intent.setPackage(packageName)
            }
            
            startActivity(intent)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    private fun getMimeType(extension: String): String {
        return when (extension.lowercase()) {
            "pdf" -> "application/pdf"
            "doc", "docx" -> "application/msword"
            "xls", "xlsx" -> "application/vnd.ms-excel"
            "ppt", "pptx" -> "application/vnd.ms-powerpoint"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "mp4" -> "video/mp4"
            "mp3" -> "audio/mp3"
            "txt" -> "text/plain"
            else -> "*/*"
        }
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: 1
            val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: 1
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bitmap
        }

        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
        return outputStream.toByteArray()
    }
    
    private fun openWithSystemChooser(filePath: String): Boolean {
        try {
            val file = File(filePath)
            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.provider",
                file
            )

            val intent = Intent(Intent.ACTION_VIEW)
            intent.setDataAndType(uri, getMimeType(filePath.split(".").last()))
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            
            // Create chooser dialog with title
            val chooserIntent = Intent.createChooser(intent, "Open with")
            startActivity(chooserIntent)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
}
