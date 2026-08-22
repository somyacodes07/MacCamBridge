import Foundation
import VideoToolbox
import CoreMedia

final class H264Decoder {

    var onDecodedFrame: ((CMSampleBuffer) -> Void)?

    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?

    private let decoderQueue = DispatchQueue(label: "com.maccambridge.decoder")

    func configure(sps: Data, pps: Data) {
        decoderQueue.async { [weak self] in
            guard let self = self else { return }

            let spsPointer = sps.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress }
            let ppsPointer = pps.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress }

            guard let spsPtr = spsPointer, let ppsPtr = ppsPointer else {
                print("H264Decoder: Invalid SPS/PPS pointers")
                return
            }

            let parameterSetPointers: [UnsafePointer<UInt8>] = [spsPtr, ppsPtr]
            let parameterSetSizes: [Int] = [sps.count, pps.count]

            var formatDesc: CMVideoFormatDescription?
            let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                allocator: kCFAllocatorDefault,
                parameterSetCount: 2,
                parameterSetPointers: parameterSetPointers,
                parameterSetSizes: parameterSetSizes,
                nalUnitHeaderLength: 4,
                formatDescriptionOut: &formatDesc
            )

            guard status == noErr, let format = formatDesc else {
                print("H264Decoder: Failed to create format description (status \(status))")
                return
            }

            self.formatDescription = format
            self.createDecompressionSession(with: format)
        }
    }

    private func createDecompressionSession(with format: CMVideoFormatDescription) {
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }

        let destinationPixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferOpenGLCompatibilityKey as String: true
        ]

        var outputCallback = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: decompressionCallback,
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        var session: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: format,
            decoderSpecification: nil,
            imageBufferAttributes: destinationPixelBufferAttributes as CFDictionary,
            outputCallback: &outputCallback,
            decompressionSessionOut: &session
        )

        if status == noErr, let session = session {
            self.decompressionSession = session
            print("H264Decoder: VTDecompressionSession created successfully")
        } else {
            print("H264Decoder: Failed to create VTDecompressionSession (status \(status))")
        }
    }

    func decode(nalData: Data, pts: CMTime) {
        decoderQueue.async { [weak self] in
            guard let self = self, let session = self.decompressionSession, let format = self.formatDescription else {
                return
            }

            var blockBuffer: CMBlockBuffer?
            let bufferStatus = nalData.withUnsafeBytes { rawBuffer -> OSStatus in
                guard let baseAddress = rawBuffer.baseAddress else { return kCMBlockBufferNoErr }
                return CMBlockBufferCreateWithMemoryBlock(
                    allocator: kCFAllocatorDefault,
                    memoryBlock: UnsafeMutableRawPointer(mutating: baseAddress),
                    blockLength: nalData.count,
                    blockAllocator: kCFAllocatorNull,
                    customBlockSource: nil,
                    offsetToData: 0,
                    dataLength: nalData.count,
                    flags: 0,
                    blockBufferOut: &blockBuffer
                )
            }

            guard bufferStatus == kCMBlockBufferNoErr, let bBuffer = blockBuffer else {
                print("H264Decoder: CMBlockBuffer creation failed (\(bufferStatus))")
                return
            }

            var sampleBuffer: CMSampleBuffer?
            var sampleTiming = CMSampleTimingInfo(
                duration: .invalid,
                presentationTimeStamp: pts,
                decodeTimeStamp: .invalid
            )

            let sampleSizeArray = [nalData.count]
            let sampleStatus = CMSampleBufferCreateReady(
                allocator: kCFAllocatorDefault,
                dataBuffer: bBuffer,
                formatDescription: format,
                sampleCount: 1,
                sampleTimingEntryCount: 1,
                sampleTimingArray: &sampleTiming,
                sampleSizeEntryCount: 1,
                sampleSizeArray: sampleSizeArray,
                sampleBufferOut: &sampleBuffer
            )

            guard sampleStatus == noErr, let sBuffer = sampleBuffer else {
                print("H264Decoder: CMSampleBuffer creation failed (\(sampleStatus))")
                return
            }

            let flags: VTDecodeFrameFlags = [._EnableAsynchronousDecompression]
            var flagOut = VTDecodeInfoFlags()

            VTDecompressionSessionDecodeFrame(
                session,
                sampleBuffer: sBuffer,
                flags: flags,
                infoFlagsOut: &flagOut,
                outputHandler: { [weak self] status, infoFlags, imageBuffer, presentationTimeStamp, presentationDuration in
                    guard status == noErr, let imageBuffer = imageBuffer else { return }

                    var timing = CMSampleTimingInfo(
                        duration: presentationDuration,
                        presentationTimeStamp: presentationTimeStamp,
                        decodeTimeStamp: .invalid
                    )
                    var formatDesc: CMVideoFormatDescription?
                    CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: imageBuffer, formatDescriptionOut: &formatDesc)

                    if let formatDesc = formatDesc {
                        var decodedSampleBuffer: CMSampleBuffer?
                        CMSampleBufferCreateForImageBuffer(
                            allocator: kCFAllocatorDefault,
                            imageBuffer: imageBuffer,
                            dataReady: true,
                            makeDataReadyCallback: nil,
                            refcon: nil,
                            formatDescription: formatDesc,
                            sampleTiming: &timing,
                            sampleBufferOut: &decodedSampleBuffer
                        )

                        if let decodedBuffer = decodedSampleBuffer {
                            self?.onDecodedFrame?(decodedBuffer)
                        }
                    }
                }
            )
        }
    }

    func invalidate() {
        decoderQueue.async { [weak self] in
            if let session = self?.decompressionSession {
                VTDecompressionSessionInvalidate(session)
                self?.decompressionSession = nil
            }
            self?.formatDescription = nil
        }
    }
}

private func decompressionCallback(
    decompressionOutputRefCon: UnsafeMutableRawPointer?,
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTDecodeInfoFlags,
    imageBuffer: CVImageBuffer?,
    presentationTimeStamp: CMTime,
    presentationDuration: CMTime
) {
    // Handled in outputHandler block above
}
