import Foundation

final class EncoderDebugSink:
    EncodedFrameSink {

    private var frameCount = 0

    func handleEncodedFrame(
        _ frame: EncodedFrame
    ) {

        switch frame.type {

        case .configuration:

            print(
                "Encoder configuration received"
            )

            if let sps = frame.sps {

                print(
                    "SPS: \(sps.count) bytes"
                )
            }

            if let pps = frame.pps {

                print(
                    "PPS: \(pps.count) bytes"
                )
            }

        case .keyFrame:

            frameCount += 1

            print(
                "Keyframe \(frameCount): \(frame.data.count) bytes"
            )

        case .deltaFrame:

            frameCount += 1

            if frameCount % 60 == 0 {

                print(
                    "Frames encoded: \(frameCount)"
                )
            }
        }
    }
}
