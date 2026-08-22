/**
 * MacCam Bridge Binary Stream Protocol Decoder (MCB1)
 * Decodes incoming TCP binary packets sent by MacCam Bridge Sender (macOS Swift App)
 */

class MCBProtocolDecoder {
    constructor() {
        this.MAGIC = 0x4D434231; // "MCB1"
        this.HEADER_SIZE = 19;    // Magic (4) + Version (1) + Type (1) + Reserved (2) + Length (4) + PTS Value (8) - timescale handled
        this.buffer = new Uint8Array(0);
        this.sps = null;
        this.pps = null;
    }

    /**
     * Appends new incoming binary chunk to internal buffer
     * @param {Uint8Array} chunk 
     * @returns {Array<Object>} List of parsed packets
     */
    append(chunk) {
        // Concatenate buffers
        const newBuf = new Uint8Array(this.buffer.length + chunk.length);
        newBuf.set(this.buffer, 0);
        newBuf.set(chunk, this.buffer.length);
        this.buffer = newBuf;

        const packets = [];

        while (this.buffer.length >= 19) {
            const view = new DataView(this.buffer.buffer, this.buffer.byteOffset, this.buffer.byteLength);
            
            // Check Magic Header ("MCB1")
            const magic = view.getUint32(0, false); // Big endian
            if (magic !== this.MAGIC) {
                // Search for magic byte alignment
                let magicIndex = -1;
                for (let i = 1; i <= this.buffer.length - 4; i++) {
                    if (view.getUint32(i, false) === this.MAGIC) {
                        magicIndex = i;
                        break;
                    }
                }

                if (magicIndex !== -1) {
                    this.buffer = this.buffer.subarray(magicIndex);
                    continue;
                } else {
                    // Retain last 3 bytes in case magic is split across chunks
                    this.buffer = this.buffer.subarray(Math.max(0, this.buffer.length - 3));
                    break;
                }
            }

            const version = view.getUint8(4);
            const packetType = view.getUint8(5);
            // reserved: bytes 6..7
            const payloadLength = view.getUint32(8, false);
            const ptsValue = view.getBigInt64(12, false);
            // ptsTimescale: bytes 20..23 if header is 24 bytes.
            
            // Fixed total header length = 4 + 1 + 1 + 2 + 4 + 8 + 4 = 24 bytes
            const TOTAL_HEADER_LEN = 24;

            if (this.buffer.length < TOTAL_HEADER_LEN + payloadLength) {
                // Insufficient data for full payload, wait for next chunk
                break;
            }

            const ptsTimescale = view.getInt32(20, false);
            const payload = this.buffer.subarray(TOTAL_HEADER_LEN, TOTAL_HEADER_LEN + payloadLength);

            packets.push({
                type: packetType, // 1 = Config (SPS/PPS), 2 = Keyframe, 3 = Deltaframe
                pts: Number(ptsValue) / (ptsTimescale || 1000),
                payload: payload
            });

            // Advance buffer
            this.buffer = this.buffer.subarray(TOTAL_HEADER_LEN + payloadLength);
        }

        return packets;
    }

    /**
     * Extracts Annex-B formatted NAL units for H.264 WebCodecs decoding
     * @param {Object} packet 
     * @returns {Uint8Array|null}
     */
    toAnnexB(packet) {
        const startCode = new Uint8Array([0, 0, 0, 1]);

        if (packet.type === 1) { // Configuration (SPS & PPS)
            const view = new DataView(packet.payload.buffer, packet.payload.byteOffset, packet.payload.byteLength);
            const spsLen = view.getUint32(0, false);
            const sps = packet.payload.subarray(4, 4 + spsLen);
            
            const ppsLen = view.getUint32(4 + spsLen, false);
            const pps = packet.payload.subarray(4 + spsLen + 4, 4 + spsLen + 4 + ppsLen);

            this.sps = sps;
            this.pps = pps;

            const annexBConfig = new Uint8Array(startCode.length + sps.length + startCode.length + pps.length);
            annexBConfig.set(startCode, 0);
            annexBConfig.set(sps, startCode.length);
            annexBConfig.set(startCode, startCode.length + sps.length);
            annexBConfig.set(pps, startCode.length + sps.length + startCode.length);

            return annexBConfig;
        } else {
            // NAL payload formatted frame
            // VideoToolbox AVCC format uses 4-byte length prefix per NALU; convert to AnnexB (0x00000001)
            let rawPayload = packet.payload;
            let resultParts = [];
            let offset = 0;

            while (offset + 4 < rawPayload.length) {
                const view = new DataView(rawPayload.buffer, rawPayload.byteOffset + offset, 4);
                const naluLen = view.getUint32(0, false);
                
                if (naluLen === 0 || offset + 4 + naluLen > rawPayload.length) {
                    // Standard AVCC or raw AnnexB fallback
                    break;
                }

                resultParts.push(startCode);
                resultParts.push(rawPayload.subarray(offset + 4, offset + 4 + naluLen));
                offset += 4 + naluLen;
            }

            if (resultParts.length === 0) {
                // Already AnnexB
                const combined = new Uint8Array(startCode.length + rawPayload.length);
                combined.set(startCode, 0);
                combined.set(rawPayload, startCode.length);
                return combined;
            }

            // Combine all NAL units with 0x00000001 start codes
            let totalLen = resultParts.reduce((acc, p) => acc + p.length, 0);
            let combined = new Uint8Array(totalLen);
            let writePos = 0;
            for (let part of resultParts) {
                combined.set(part, writePos);
                writePos += part.length;
            }

            return combined;
        }
    }
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { MCBProtocolDecoder };
}
