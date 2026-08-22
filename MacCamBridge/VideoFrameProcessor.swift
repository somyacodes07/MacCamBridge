import Foundation
import AVFoundation
import CoreVideo
import CoreMedia

/// Protocol for components that consume raw video frames from the camera capture pipeline.
protocol VideoFrameConsumer: AnyObject {
    func processVideoFrame(_ sampleBuffer: CMSampleBuffer)
}

/// Dedicated sample buffer delegate for `AVCaptureVideoDataOutput`.
/// Operates on a background serial queue, processes frame metadata, performs controlled diagnostic logging,
/// and dispatches `CMSampleBuffer` instances to downstream consumers without blocking the main UI thread.
final class VideoFrameProcessor:
    NSObject,
    AVCaptureVideoDataOutputSampleBufferDelegate {

    private(set) var frameCount: Int64 = 0
    private var lastLogTime: CFAbsoluteTime = 0
    private var lastLogFrameCount: Int64 = 0

    /// Periodic logging interval in frames (e.g. log every 60 frames ~ 2 seconds at 30fps)
    var diagnosticLogInterval: Int64 = 60
    var isDiagnosticLoggingEnabled: Bool = true

    /// Downstream frame consumers (e.g., encoders, WebRTC streams, diagnostic sinks)
    private var consumers: [VideoFrameConsumer] = []

    override init() {
        super.init()
    }

    init(consumers: [VideoFrameConsumer]) {
        self.consumers = consumers
        super.init()
    }

    func addConsumer(_ consumer: VideoFrameConsumer) {
        consumers.append(consumer)
    }

    func removeAllConsumers() {
        consumers.removeAll()
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameCount += 1

        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            print(
                "Frame size:",
                CVPixelBufferGetWidth(pixelBuffer),
                "x",
                CVPixelBufferGetHeight(pixelBuffer)
            )
        }

        // Controlled diagnostic logging
        if isDiagnosticLoggingEnabled && frameCount % diagnosticLogInterval == 0 {
            logFrameDiagnostics(sampleBuffer: sampleBuffer)
        }

        // Forward CMSampleBuffer to registered consumers
        for consumer in consumers {
            consumer.processVideoFrame(sampleBuffer)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        print("[VideoFrameProcessor] Warning: Frame dropped by capture output")
    }

    // MARK: - Diagnostic Helpers

    private func logFrameDiagnostics(sampleBuffer: CMSampleBuffer) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        var width = 0
        var height = 0
        var pixelFormatString = "unknown"

        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            width = CVPixelBufferGetWidth(pixelBuffer)
            height = CVPixelBufferGetHeight(pixelBuffer)
            let formatType = CVPixelBufferGetPixelFormatType(pixelBuffer)
            pixelFormatString = fourCCString(from: formatType)
        }

        var fps: Double = 0.0
        if lastLogTime > 0 {
            let elapsedTime = currentTime - lastLogTime
            let framesDelta = frameCount - lastLogFrameCount
            if elapsedTime > 0 {
                fps = Double(framesDelta) / elapsedTime
            }
        }

        lastLogTime = currentTime
        lastLogFrameCount = frameCount

        let ptsSeconds = String(format: "%.3f", pts.seconds)
        let fpsString = fps > 0 ? String(format: "%.1f", fps) : "--"

        print("[VideoFrameProcessor] Frame #\(frameCount) | \(width)x\(height) | Format: \(pixelFormatString) | PTS: \(ptsSeconds)s | FPS: \(fpsString)")
    }

    private func fourCCString(from format: OSType) -> String {
        let bytes: [CChar] = [
            CChar((format >> 24) & 0xff),
            CChar((format >> 16) & 0xff),
            CChar((format >> 8) & 0xff),
            CChar(format & 0xff),
            0
        ]
        return String(cString: bytes)
    }
}

