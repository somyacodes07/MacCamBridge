import Foundation
import CoreMedia

enum EncodedFrameType {
    case configuration
    case keyFrame
    case deltaFrame
}

struct EncodedFrame {

    let type: EncodedFrameType
    let data: Data
    let pts: CMTime

    let sps: Data?
    let pps: Data?

    init(
        type: EncodedFrameType,
        data: Data,
        pts: CMTime,
        sps: Data? = nil,
        pps: Data? = nil
    ) {
        self.type = type
        self.data = data
        self.pts = pts
        self.sps = sps
        self.pps = pps
    }
}

protocol EncodedFrameSink: AnyObject {
    func handleEncodedFrame(
        _ frame: EncodedFrame
    )
}
