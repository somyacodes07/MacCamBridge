import SwiftUI
import AVFoundation

final class SampleBufferView: NSView {

    let displayLayer = AVSampleBufferDisplayLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        wantsLayer = true
        layer = displayLayer
        displayLayer.videoGravity = .resizeAspect
    }

    override func layout() {
        super.layout()
        displayLayer.frame = bounds
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        if #available(macOS 15.0, *) {
            if displayLayer.sampleBufferRenderer.status == .failed {
                displayLayer.sampleBufferRenderer.flush()
            }
            displayLayer.sampleBufferRenderer.enqueue(sampleBuffer)
        } else {
            if displayLayer.status == .failed {
                displayLayer.flush()
            }
            displayLayer.enqueue(sampleBuffer)
        }
    }

    func flush() {
        if #available(macOS 15.0, *) {
            displayLayer.sampleBufferRenderer.flush()
        } else {
            displayLayer.flush()
        }
    }
}

struct SampleBufferDisplayView: NSViewRepresentable {

    let sampleBuffer: CMSampleBuffer?

    func makeNSView(context: Context) -> SampleBufferView {
        let view = SampleBufferView()
        return view
    }

    func updateNSView(_ nsView: SampleBufferView, context: Context) {
        if let buffer = sampleBuffer {
            nsView.enqueue(buffer)
        }
    }
}
