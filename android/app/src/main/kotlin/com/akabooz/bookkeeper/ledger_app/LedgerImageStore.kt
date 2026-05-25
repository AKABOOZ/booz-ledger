package com.akabooz.bookkeeper.ledger_app

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import java.io.File
import java.io.FileOutputStream

object LedgerImageStore {
    fun copyUriToCache(
        context: Context,
        uri: Uri?,
        filePrefix: String,
    ): String? {
        if (uri == null) {
            return null
        }
        return try {
            val extension = extensionForMimeType(context.contentResolver.getType(uri))
            val file = File(context.cacheDir, "${filePrefix}_${System.currentTimeMillis()}$extension")
            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(file).use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            file.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    fun writeBitmapToCache(
        context: Context,
        bitmap: Bitmap,
        filePrefix: String,
    ): String? {
        return try {
            val file = File(context.cacheDir, "${filePrefix}_${System.currentTimeMillis()}.png")
            FileOutputStream(file).use { output ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
            }
            file.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun extensionForMimeType(mimeType: String?): String {
        return when (mimeType) {
            "image/png" -> ".png"
            "image/webp" -> ".webp"
            else -> ".jpg"
        }
    }
}
