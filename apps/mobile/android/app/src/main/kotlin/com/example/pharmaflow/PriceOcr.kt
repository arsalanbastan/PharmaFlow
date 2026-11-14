package com.example.pharmaflow

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

internal fun Activity.configurePriceOcr(messenger: BinaryMessenger) {
    val context = applicationContext
    MethodChannel(messenger, "pharmaflow/price_ocr").setMethodCallHandler { call, result ->
        if (call.method != "readCells") {
            result.notImplemented()
            return@setMethodCallHandler
        }
        val bytes = call.argument<ByteArray>("image")
        val cells = call.argument<List<List<Double>>>("cells")
        if (bytes == null || bytes.isEmpty() || bytes.size > 6 * 1024 * 1024 ||
            cells == null || cells.size !in 1..100 ||
            cells.any { cell -> cell.size != 4 || cell.any { it !in 0.0..1.0 } ||
                cell[0] >= cell[2] || cell[1] >= cell[3] }
        ) {
            result.error("INVALID_IMAGE", "تصویر یا محدوده‌های انتخاب‌شده معتبر نیست.", null)
            return@setMethodCallHandler
        }
        val reply = result
        Thread {
            try {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                require(bounds.outWidth > 0 && bounds.outHeight > 0)
                var sample = 1
                while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 3600) sample *= 2
                val bitmap = BitmapFactory.decodeByteArray(
                    bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample },
                ) ?: error("Invalid image")
                try {
                    val root = File(context.filesDir, "price-ocr-v1")
                    val data = File(root, "tessdata").apply { mkdirs() }
                    val engine = TessBaseAPI()
                    try {
                        synchronized(PriceOcrAssets) {
                            for (language in listOf("fas", "eng")) {
                                val name = "$language.traineddata"
                                val target = File(data, name)
                                if (!target.exists()) {
                                    val temporary = File(data, "$name.tmp")
                                    context.assets.open("tessdata/$name").use { input ->
                                        temporary.outputStream().use { output -> input.copyTo(output) }
                                    }
                                    check(temporary.renameTo(target))
                                }
                            }
                        }
                        check(engine.init(root.absolutePath, "fas+eng"))
                        val values = cells.mapIndexed { index, cell ->
                            val priceCell = index % 2 == 1
                            engine.setPageSegMode(
                                if (priceCell) TessBaseAPI.PageSegMode.PSM_SINGLE_LINE
                                else TessBaseAPI.PageSegMode.PSM_SINGLE_BLOCK,
                            )
                            engine.setVariable(
                                "tessedit_char_whitelist",
                                if (priceCell) "0123456789۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩.,٬،" else "",
                            )
                            val left = (cell[0] * bitmap.width).toInt().coerceIn(0, bitmap.width - 1)
                            val top = (cell[1] * bitmap.height).toInt().coerceIn(0, bitmap.height - 1)
                            val right = (cell[2] * bitmap.width).toInt().coerceIn(left + 1, bitmap.width)
                            val bottom = (cell[3] * bitmap.height).toInt().coerceIn(top + 1, bitmap.height)
                            val crop = Bitmap.createBitmap(bitmap, left, top, right - left, bottom - top)
                            val scaled = if (crop.height < 64) {
                                val factor = minOf(3.0, 64.0 / crop.height)
                                Bitmap.createScaledBitmap(
                                    crop, (crop.width * factor).toInt(), (crop.height * factor).toInt(), true,
                                )
                            } else crop
                            try {
                                engine.setImage(scaled)
                                val text = engine.getUTF8Text().orEmpty().trim()
                                if (priceCell && engine.meanConfidence() < 75) "" else text
                            } finally {
                                if (scaled !== crop) scaled.recycle()
                                if (crop !== bitmap) crop.recycle()
                            }
                        }
                        runOnUiThread { reply.success(values) }
                    } finally {
                        engine.recycle()
                    }
                } finally {
                    bitmap.recycle()
                }
            } catch (_: Exception) {
                runOnUiThread { reply.error("OCR_FAILED", "خواندن آفلاین تصویر انجام نشد.", null) }
            } catch (_: UnsatisfiedLinkError) {
                runOnUiThread { reply.error("OCR_UNAVAILABLE", "موتور خواندن تصویر در دسترس نیست.", null) }
            }
        }.start()
    }
}

private object PriceOcrAssets
