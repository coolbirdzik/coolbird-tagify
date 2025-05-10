package com.example.cb_file_manager

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "cb_file_manager/external_apps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
