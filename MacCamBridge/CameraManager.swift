import Foundation
import AVFoundation
import Combine

final class CameraManager: NSObject, ObservableObject {

    @Published var isRunning = false

    let session = AVCaptureSession()

    let streamServer = StreamServer()

    private let debugSink =
        EncoderDebugSink()

    private var frameSink:
        FrameSinkMultiplexer?

    private let sessionQueue =
        DispatchQueue(
            label: "com.maccambridge.camera"
        )

    private var videoOutput:
        AVCaptureVideoDataOutput?

    private var processor:
        VideoFrameProcessor?

    private var encoder:
        H264Encoder?

    private var isConfigured = false

    override init() {

        super.init()

        streamServer.start(
            port: 8080
        )

        setupCamera()
    }

    private func setupCamera() {

        sessionQueue.async {
            [weak self] in

            guard let self = self else {
                return
            }

            guard !self.isConfigured else {
                return
            }

            self.session.beginConfiguration()

            self.session.sessionPreset =
                .hd1920x1080

            guard
                let camera =
                    AVCaptureDevice.default(
                        for: .video
                    )
            else {

                print(
                    "Camera not found"
                )

                self.session.commitConfiguration()

                return
            }

            print(
                "Using camera: \(camera.localizedName)"
            )

            do {

                let input =
                    try AVCaptureDeviceInput(
                        device: camera
                    )

                if self.session.canAddInput(
                    input
                ) {

                    self.session.addInput(
                        input
                    )

                } else {

                    print(
                        "Cannot add camera input"
                    )

                    self.session.commitConfiguration()

                    return
                }

            } catch {

                print(
                    "Failed to create camera input: \(error)"
                )

                self.session.commitConfiguration()

                return
            }

            let output =
                AVCaptureVideoDataOutput()

            output.alwaysDiscardsLateVideoFrames =
                true

            output.videoSettings = [

                kCVPixelBufferPixelFormatTypeKey
                    as String:
                    kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            ]

            let encoder =
                H264Encoder(
                    width: 1080,
                    height: 1920,
                    fps: 30,
                    bitrate: 8_000_000
                )

            let frameSink =
                FrameSinkMultiplexer(
                    sinks: [
                        self.debugSink,
                        self.streamServer
                    ]
                )

            encoder.sink = frameSink

            let processor =
                VideoFrameProcessor(
                    consumers: [encoder]
                )

            let videoQueue =
                DispatchQueue(
                    label:
                        "com.maccambridge.video"
                )

            output.setSampleBufferDelegate(
                processor,
                queue: videoQueue
            )

            if self.session.canAddOutput(
                output
            ) {

                self.session.addOutput(
                    output
                )

            } else {

                print(
                    "Cannot add video output"
                )

                self.session.commitConfiguration()

                return
            }

            if let connection = output.connection(with: .video),
               connection.isVideoOrientationSupported {

                connection.videoOrientation = .landscapeRight
            }

            self.encoder = encoder
            self.processor = processor
            self.videoOutput = output
            self.frameSink = frameSink

            self.session.commitConfiguration()

            self.isConfigured = true

            print(
                "Camera pipeline configured"
            )
        }
    }

    func start() {

        sessionQueue.async {
            [weak self] in

            guard let self = self else {
                return
            }

            guard self.isConfigured else {

                print(
                    "Camera is not configured yet"
                )

                return
            }

            if !self.streamServer.isRunning {
                self.streamServer.start(
                    port: 8080
                )
            }

            guard
                !self.session.isRunning
            else {
                return
            }

            self.encoder?.start()

            self.session.startRunning()

            DispatchQueue.main.async {

                self.isRunning = true
            }

            print(
                "Camera started"
            )
        }
    }

    func stop() {

        sessionQueue.async {
            [weak self] in

            guard let self = self else {
                return
            }

            guard
                self.session.isRunning
            else {
                return
            }

            self.session.stopRunning()

            self.encoder?.stop()

            DispatchQueue.main.async {

                self.isRunning = false
            }

            print(
                "Camera stopped"
            )
        }
    }

    deinit {

        if session.isRunning {

            session.stopRunning()
        }

        encoder?.stop()

        streamServer.stop()
    }
}
