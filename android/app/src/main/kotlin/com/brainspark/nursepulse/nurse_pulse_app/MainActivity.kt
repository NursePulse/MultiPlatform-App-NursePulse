package com.brainspark.nursepulse.nurse_pulse_app

import io.flutter.embedding.android.FlutterActivity
import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val savePdfRequest = 4517
    private var pdfBytes: ByteArray? = null
    private var pdfResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nursepulse/audit_pdf")
            .setMethodCallHandler { call, result ->
                if (call.method != "save") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pdfResult != null) {
                    result.error("BUSY", "Hay un guardado en curso.", null)
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || bytes.size < 5 || String(bytes.copyOfRange(0, 5), Charsets.US_ASCII) != "%PDF-") {
                    result.error("INVALID_PDF", "Documento inválido.", null)
                    return@setMethodCallHandler
                }
                pdfBytes = bytes
                pdfResult = result
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_TITLE, "auditoria-nursepulse.pdf")
                    }
                    startActivityForResult(intent, savePdfRequest)
                } catch (_: Exception) {
                    pdfBytes = null
                    pdfResult = null
                    result.error("SAVE_FAILED", "No se pudo elegir un destino.", null)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != savePdfRequest) return
        val result = pdfResult ?: return
        val bytes = pdfBytes
        pdfBytes = null
        pdfResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(false)
            return
        }
        Thread {
            try {
                val output = contentResolver.openOutputStream(uri, "w")
                    ?: throw IllegalStateException("Sin destino")
                output.use { it.write(bytes ?: throw IllegalStateException("Sin PDF")) }
                runOnUiThread { result.success(true) }
            } catch (_: Exception) {
                runOnUiThread { result.error("SAVE_FAILED", "No se pudo guardar el PDF.", null) }
            }
        }.start()
    }
}
