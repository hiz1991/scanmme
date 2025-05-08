import SwiftUI
import QuickLook // Needed for QLPreviewController and QLPreviewItem

// 1. QLPreviewController wrapper for SwiftUI
struct PDFQuickLookView: UIViewControllerRepresentable {
    // The URL of the PDF file to display
    let url: URL

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        
        // Presenting QLPreviewController within a UINavigationController
        // is often recommended to ensure proper toolbar display and navigation.
        let navigationController = UINavigationController(rootViewController: controller)
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No specific updates needed here for basic presentation.
        // If the URL could change, you might need to tell the QLPreviewController
        // to reload its data or update the view. For example, by accessing
        // uiViewController.viewControllers.first as? QLPreviewController
        // and calling controller.reloadData() or controller.refreshCurrentPreviewItem().
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: PDFQuickLookView

        init(parent: PDFQuickLookView) {
            self.parent = parent
        }

        // QLPreviewControllerDataSource methods
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1 // We are previewing a single PDF
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            // URL conforms to QLPreviewItem (via its Objective-C counterpart NSURL)
            return parent.url as NSURL
        }
    }
}
