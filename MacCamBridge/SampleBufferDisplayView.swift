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
        displayLayer.videoGravity = .resizeAspectFill
        displayLayer.frame = bounds
        layer?.addSublayer(displayLayer)
    }

    override func layout() {
        super.layout()
        displayLayer.frame = bounds
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(sampleBuffer)
    }

    func flush() {
        displayLayer.flush()
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
