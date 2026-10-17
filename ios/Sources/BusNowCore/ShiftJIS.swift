import Foundation

public enum ShiftJIS {
    public static func decode(_ data: Data) -> String {
        let table = Table.shared
        var scalars: [Unicode.Scalar] = []
        scalars.reserveCapacity(data.count)
        let bytes = [UInt8](data)
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte < 0x80 {
                scalars.append(Unicode.Scalar(byte))
                index += 1
                continue
            }
            if (0xA1...0xDF).contains(byte) {
                scalars.append(Unicode.Scalar(0xFF61 + UInt32(byte - 0xA1))!)
                index += 1
                continue
            }
            let isLead = (0x81...0x9F).contains(byte) || (0xE0...0xFC).contains(byte)
            if isLead, index + 1 < bytes.count {
                let key = UInt16(byte) << 8 | UInt16(bytes[index + 1])
                if let value = table[key], let scalar = Unicode.Scalar(value) {
                    scalars.append(scalar)
                    index += 2
                    continue
                }
            }
            scalars.append("\u{FFFD}")
            index += 1
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private enum Table {
        static let shared: [UInt16: UInt32] = load()

        static func load() -> [UInt16: UInt32] {
            guard let url = BundledResources.url("cp932", "bin"),
                  let data = try? Data(contentsOf: url),
                  data.count >= 8,
                  data.prefix(4) == Data("CP92".utf8)
            else {
                return [:]
            }
            let count = Int(readUInt32(data, 4))
            var map: [UInt16: UInt32] = [:]
            map.reserveCapacity(count)
            var offset = 8
            for _ in 0..<count {
                guard offset + 6 <= data.count else { break }
                let code = readUInt16(data, offset)
                let scalar = readUInt32(data, offset + 2)
                map[code] = scalar
                offset += 6
            }
            return map
        }

        static func readUInt16(_ data: Data, _ offset: Int) -> UInt16 {
            let start = data.startIndex
            return UInt16(data[data.index(start, offsetBy: offset)])
                | UInt16(data[data.index(start, offsetBy: offset + 1)]) << 8
        }

        static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
            let start = data.startIndex
            return UInt32(data[data.index(start, offsetBy: offset)])
                | UInt32(data[data.index(start, offsetBy: offset + 1)]) << 8
                | UInt32(data[data.index(start, offsetBy: offset + 2)]) << 16
                | UInt32(data[data.index(start, offsetBy: offset + 3)]) << 24
        }
    }
}

public func decodePage(_ bytes: Data) -> String {
    let headCount = min(800, bytes.count)
    let head = latin1(bytes.prefix(headCount))
    let isShiftJIS = containsMatch(head, pattern: "shift_jis|x-sjis|windows-31j", caseInsensitive: true)
    if !isShiftJIS {
        return String(data: bytes, encoding: .utf8) ?? ShiftJIS.decode(bytes)
    }
    let text = ShiftJIS.decode(bytes)
    if !containsJapanese(String(text.prefix(4000))) {
        return String(data: bytes, encoding: .utf8) ?? text
    }
    return text
}

func latin1(_ data: Data) -> String {
    var scalars: [Unicode.Scalar] = []
    scalars.reserveCapacity(data.count)
    for byte in data {
        scalars.append(Unicode.Scalar(byte))
    }
    return String(String.UnicodeScalarView(scalars))
}

enum BundledResources {
    static func url(_ name: String, _ ext: String) -> URL? {
        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }
        if let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources") {
            return url
        }
        if let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") {
            return url
        }
        return nil
    }

    static func text(_ name: String, _ ext: String) throws -> String {
        guard let url = url(name, ext) else {
            throw BusTransportError("同梱データがありません: \(name).\(ext)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
