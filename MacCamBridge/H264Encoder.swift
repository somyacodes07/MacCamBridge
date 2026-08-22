import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo

final class H264Encoder: VideoFrameConsumer {

    func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        encode(pixelBuffer: pixelBuffer, pts: pts)
    }

    private var session: VTCompressionSession?

    private let width: Int32
    private let height: Int32
    private let fps: Int32
    private let bitrate: Int

    private let callbackQueue = DispatchQueue(
        label: "com.maccambridge.encoder.callback"
    )

    weak var sink: EncodedFrameSink?

    init(
        width: Int32,
        height: Int32,
        fps: Int32,
        bitrate: Int
    ) {
        self.width = width
        self.height = height
        self.fps = fps
        self.bitrate = bitrate
    }

    func start() {
        guard session == nil else {
            return
        }

        createSession()
    }

    func stop() {
        guard let session = session else {
            return
        }

        VTCompressionSessionCompleteFrames(
            session,
            untilPresentationTimeStamp: .invalid
        )

        VTCompressionSessionInvalidate(session)

        self.session = nil

        print("H264 encoder stopped")
    }

    func encode(
        pixelBuffer: CVPixelBuffer,
        pts: CMTime
    ) {
        guard let session = session else {
            return
        }

        var flags = VTEncodeInfoFlags()

        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )

        if status != noErr {
            print(
                "VTCompressionSessionEncodeFrame failed: \(status)"
            )
        }
    }

    private func createSession() {

        var sessionOut: VTCompressionSession?

        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: H264Encoder.outputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &sessionOut
        )

        guard
            status == noErr,
            let session = sessionOut
        else {
            print(
                "VTCompressionSessionCreate failed: \(status)"
            )
            return
        }

        self.session = session

        configure(session: session)

        let prepareStatus =
            VTCompressionSessionPrepareToEncodeFrames(
                session
            )

        if prepareStatus != noErr {

            print(
                "VTCompressionSessionPrepareToEncodeFrames failed: \(prepareStatus)"
            )

            VTCompressionSessionInvalidate(session)

            self.session = nil

            return
        }

        print("H264 encoder started")
    }

    private func configure(
        session: VTCompressionSession
    ) {

        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_RealTime,
            value: kCFBooleanTrue
        )

        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_AllowFrameReordering,
            value: kCFBooleanFalse
        )

        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_ProfileLevel,
            value: kVTProfileLevel_H264_High_AutoLevel
        )

        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_AverageBitRate,
            value: NSNumber(value: bitrate)
        )

        let bytesPerSecond = bitrate / 8

        let dataRateLimits: [NSNumber] = [
            NSNumber(value: bytesPerSecond),
            NSNumber(value: 1)
        ]

        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_DataRateLimits,
            value: dataRateLimits as NSArray
        )

        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_ExpectedFrameRate,
            value: NSNumber(value: fps)
        )

        let keyFrameInterval = Int(fps * 2)

        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
            value: NSNumber(value: keyFrameInterval)
        )

        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,
            value: NSNumber(value: 2)
        )
    }

    private static let outputCallback:
        VTCompressionOutputCallback = {

            refCon,
            sourceFrameRefCon,
            status,
            infoFlags,
            sampleBuffer in

            guard
                status == noErr,
                let sampleBuffer = sampleBuffer,
                CMSampleBufferDataIsReady(sampleBuffer)
            else {

                if status != noErr {
                    print(
                        "Encoder callback failed: \(status)"
                    )
                }

                return
            }

            guard let refCon = refCon else {
                return
            }

            let encoder =
                Unmanaged<H264Encoder>
                    .fromOpaque(refCon)
                    .takeUnretainedValue()

            let pts =
                CMSampleBufferGetPresentationTimeStamp(
                    sampleBuffer
                )

            var isKeyFrame = false

            if
                let attachments =
                    CMSampleBufferGetSampleAttachmentsArray(
                        sampleBuffer,
                        createIfNecessary: false
                    ) as? [[CFString: Any]],

                let firstAttachment = attachments.first {

                let notSync =
                    firstAttachment[
                        kCMSampleAttachmentKey_NotSync
                    ] as? Bool ?? false

                isKeyFrame = !notSync
            }

            var spsData: Data?
            var ppsData: Data?

            if isKeyFrame,
               let formatDescription =
                    CMSampleBufferGetFormatDescription(
                        sampleBuffer
                    ) {

                var spsPointer: UnsafePointer<UInt8>?
                var spsLength: Int = 0
                var parameterSetCount: Int = 0
                var nalUnitHeaderLength: Int32 = 0

                let spsStatus =
                    CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                        formatDescription,
                        parameterSetIndex: 0,
                        parameterSetPointerOut: &spsPointer,
                        parameterSetSizeOut: &spsLength,
                        parameterSetCountOut: &parameterSetCount,
                        nalUnitHeaderLengthOut: &nalUnitHeaderLength
                    )

                if
                    spsStatus == noErr,
                    let spsPointer = spsPointer {

                    spsData = Data(
                        bytes: spsPointer,
                        count: spsLength
                    )
                }

                var ppsPointer: UnsafePointer<UInt8>?
                var ppsLength = 0

                let ppsStatus =
                    CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                        formatDescription,
                        parameterSetIndex: 1,
                        parameterSetPointerOut: &ppsPointer,
                        parameterSetSizeOut: &ppsLength,
                        parameterSetCountOut: nil,
                        nalUnitHeaderLengthOut: nil
                    )

                if
                    ppsStatus == noErr,
                    let ppsPointer = ppsPointer {

                    ppsData = Data(
                        bytes: ppsPointer,
                        count: ppsLength
                    )
                }
            }

            guard
                let dataBuffer =
                    CMSampleBufferGetDataBuffer(
                        sampleBuffer
                    )
            else {
                return
            }

            var lengthAtOffset = 0
            var totalLength = 0

            var dataPointer:
                UnsafeMutablePointer<Int8>?

            let blockStatus =
                CMBlockBufferGetDataPointer(
                    dataBuffer,
                    atOffset: 0,
                    lengthAtOffsetOut: &lengthAtOffset,
                    totalLengthOut: &totalLength,
                    dataPointerOut: &dataPointer
                )

            guard
                blockStatus == kCMBlockBufferNoErr,
                let dataPointer = dataPointer
            else {

                print(
                    "Failed to access encoded frame data"
                )

                return
            }

            let data = Data(
                bytes: dataPointer,
                count: totalLength
            )

            let frameType: EncodedFrameType =
                isKeyFrame
                ? .keyFrame
                : .deltaFrame

            let frame = EncodedFrame(
                type: frameType,
                data: data,
                pts: pts,
                sps: spsData,
                pps: ppsData
            )

            encoder.callbackQueue.async {

                encoder.sink?.handleEncodedFrame(
                    frame
                )
            }
        }

    deinit {
        stop()
    }
}
