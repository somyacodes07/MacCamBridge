import SwiftUI
import AVFoundation

final class PreviewView: NSView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func makeBackingLayer() -> CALayer {
        CALayer()
    }

    func setSession(_ session: AVCaptureSession) {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds

        layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        layer?.addSublayer(previewLayer)
    }

    override func layout() {
        super.layout()

        layer?.sublayers?.first?.frame = bounds
    }
}

struct CameraPreview: NSViewRepresentable {

    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.setSession(session)
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        // Preview updates automatically
    }
}
