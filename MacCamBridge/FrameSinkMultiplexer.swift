import Foundation

final class FrameSinkMultiplexer: EncodedFrameSink {

    private let sinks: [EncodedFrameSink]

    init(
        sinks: [EncodedFrameSink]
    ) {

        self.sinks = sinks
    }

    func handleEncodedFrame(
        _ frame: EncodedFrame
    ) {

        for sink in sinks {

            sink.handleEncodedFrame(
                frame
            )
        }
    }
}
