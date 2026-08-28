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
            kCVPixelBufferMetalCompatibilityKey as String: true
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
                guard let baseAddress = rawBuffer.baseAddress else { return -1 }
                
                var createdBuffer: CMBlockBuffer?
                let createStatus = CMBlockBufferCreateWithMemoryBlock(
                    allocator: kCFAllocatorDefault,
                    memoryBlock: nil,
                    blockLength: nalData.count,
                    blockAllocator: kCFAllocatorDefault,
                    customBlockSource: nil,
                    offsetToData: 0,
                    dataLength: nalData.count,
                    flags: 0,
                    blockBufferOut: &createdBuffer
                )
                
                guard createStatus == kCMBlockBufferNoErr, let created = createdBuffer else {
                    return createStatus
                }
                
                let copyStatus = CMBlockBufferReplaceDataBytes(
                    with: baseAddress,
                    blockBuffer: created,
                    offsetIntoDestination: 0,
                    dataLength: nalData.count
                )
                
                if copyStatus == kCMBlockBufferNoErr {
                    blockBuffer = created
                }
                return copyStatus
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
                    guard status == noErr, let imageBuffer = imageBuffer else {
                        if status != noErr {
                            print("H264Decoder: Frame decompression failed with error \(status)")
                        }
                        return
                    }

                    var timing = CMSampleTimingInfo(
                        duration: presentationDuration.isValid ? presentationDuration : .invalid,
                        presentationTimeStamp: presentationTimeStamp,
                        decodeTimeStamp: .invalid
                    )
                    var formatDesc: CMVideoFormatDescription?
                    let descStatus = CMVideoFormatDescriptionCreateForImageBuffer(
                        allocator: kCFAllocatorDefault,
                        imageBuffer: imageBuffer,
                        formatDescriptionOut: &formatDesc
                    )

                    if descStatus == noErr, let formatDesc = formatDesc {
                        var decodedSampleBuffer: CMSampleBuffer?
                        let sampleStatus = CMSampleBufferCreateForImageBuffer(
                            allocator: kCFAllocatorDefault,
                            imageBuffer: imageBuffer,
                            dataReady: true,
                            makeDataReadyCallback: nil,
                            refcon: nil,
                            formatDescription: formatDesc,
                            sampleTiming: &timing,
                            sampleBufferOut: &decodedSampleBuffer
                        )

                        if sampleStatus == noErr, let decodedBuffer = decodedSampleBuffer {
                            // Ensure AVSampleBufferDisplayLayer displays immediately without waiting on an external timebase
                            if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(decodedBuffer, createIfNecessary: true) {
                                let count = CFArrayGetCount(attachmentsArray)
                                for i in 0..<count {
                                    let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachmentsArray, i), to: CFMutableDictionary.self)
                                    CFDictionarySetValue(
                                        dict,
                                        Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                        Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
                                    )
                                }
                            }

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
