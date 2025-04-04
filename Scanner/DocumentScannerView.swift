import SwiftUI
import VisionKit // Import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    // Environment variable to dismiss the view controller
    @Environment(\.dismiss) var dismiss
    // Callback to pass the scanned results back
    var onScanResult: (Result<VNDocumentCameraScan, Error>) -> Void

    // Creates the UIKit view controller
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let documentViewController = VNDocumentCameraViewController()
        // Set the delegate to the Coordinator
        documentViewController.delegate = context.coordinator
        return documentViewController
    }

    // Updates the view controller (not usually needed for this simple case)
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No update needed
    }

    // Creates the Coordinator to handle delegate methods
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator
    // Handles delegate callbacks from VNDocumentCameraViewController
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }

        // Called when scanning is successfully completed
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            print("Document scan successful. Pages: \(scan.pageCount)")
            // Pass the successful scan result back via the callback
            parent.onScanResult(.success(scan))
            // Dismiss the scanner view
            parent.dismiss()
        }

        // Called if the user cancels the scan
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            print("Document scan cancelled.")
            // Optionally pass back a custom error or indication of cancellation
            // parent.onScanResult(.failure(ScanError.userCancelled))
            parent.dismiss()
        }

        // Called if an error occurs during scanning
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scan failed with error: \(error.localizedDescription)")
            // Pass the error back via the callback
            parent.onScanResult(.failure(error))
            parent.dismiss()
        }
    }
}

// Optional: Define custom errors if needed
// enum ScanError: Error {
//     case userCancelled
// }

// --- ADDED: Placeholder for DocumentScannerView ---
// You should create DocumentScannerView.swift as shown in the Canvas
// This is just to make HomeScreenView compile for the patch context
//struct DocumentScannerView: View {
//    var onScanResult: (Result<VNDocumentCameraScan, Error>) -> Void
//    var body: some View {
//        Text("Placeholder for DocumentScannerView")
//    }
//}
