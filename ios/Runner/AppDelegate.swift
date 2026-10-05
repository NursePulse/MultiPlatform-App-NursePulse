import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var pdfResult: FlutterResult?
  private var pdfURL: URL?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "nursepulse/audit_pdf",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "save" else { result(FlutterMethodNotImplemented); return }
      guard let self = self else { result(FlutterError(code: "SAVE_FAILED", message: "Sin ventana", details: nil)); return }
      guard self.pdfResult == nil else { result(FlutterError(code: "BUSY", message: "Guardado en curso", details: nil)); return }
      guard let args = call.arguments as? [String: Any],
            let data = args["bytes"] as? FlutterStandardTypedData,
            data.data.starts(with: Data("%PDF-".utf8)) else {
        result(FlutterError(code: "INVALID_PDF", message: "Documento inválido", details: nil)); return
      }
      guard var controller = engineBridge.applicationRegistrar.viewController else {
        result(FlutterError(code: "SAVE_FAILED", message: "Sin ventana", details: nil)); return
      }
      while let presented = controller.presentedViewController { controller = presented }
      do {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("auditoria-nursepulse.pdf")
        try data.data.write(to: url, options: .atomic)
        self.pdfURL = url
        self.pdfResult = result
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = self
        controller.present(picker, animated: true)
      } catch {
        result(FlutterError(code: "SAVE_FAILED", message: "No se pudo guardar el PDF", details: nil))
      }
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finishPdf(!urls.isEmpty)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishPdf(false)
  }

  private func finishPdf(_ saved: Bool) {
    let result = pdfResult
    pdfResult = nil
    if let url = pdfURL { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    pdfURL = nil
    result?(saved)
  }
}
