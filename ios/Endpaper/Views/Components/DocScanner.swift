// The document camera — VisionKit's scanner wrapped for SwiftUI. Made
// for photographing written pages: it finds the page edges, corrects the
// perspective, and hands back clean captures for OCR. Multi-page in one
// session; every page joins the same committed section.

import SwiftUI
import VisionKit

struct DocScanner: UIViewControllerRepresentable {
    var onPages: ([UIImage]) -> Void

    static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPages: onPages) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onPages: ([UIImage]) -> Void
        init(onPages: @escaping ([UIImage]) -> Void) { self.onPages = onPages }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let pages = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            controller.dismiss(animated: true)
            onPages(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}
