import Foundation

public enum ShiftJISTableError: Error, Equatable {
    case missing
    case invalid
}

public enum ShiftJIS {
    public static func decode(_ data: Data) throws -> String {
        let table = try sharedTable()
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

    private static let cached: Result<[UInt16: UInt32], Error> = {
        do {
            guard let url = BundledResources.url("cp932", "bin") else {
                return .failure(ShiftJISTableError.missing)
            }
            return .success(try parseTable(Data(contentsOf: url)))
        } catch {
            return .failure(error)
        }
    }()

    static func sharedTable() throws -> [UInt16: UInt32] {
        try cached.get()
    }

    static func parseTable(_ data: Data) throws -> [UInt16: UInt32] {
        let bytes = [UInt8](data)
        guard bytes.count >= 8, bytes.starts(with: [0x43, 0x50, 0x39, 0x32]) else {
            throw ShiftJISTableError.invalid
        }
        let count = Int(readUInt32(bytes, 4))
        guard count >= 1000 else { throw ShiftJISTableError.invalid }
        var map: [UInt16: UInt32] = [:]
        map.reserveCapacity(count)
        var offset = 8
        var loaded = 0
        for _ in 0..<count {
            guard offset + 6 <= bytes.count else { break }
            let code = readUInt16(bytes, offset)
            let scalar = readUInt32(bytes, offset + 2)
            map[code] = scalar
            offset += 6
            loaded += 1
        }
        guard loaded >= 1000 else { throw ShiftJISTableError.invalid }
        return map
    }

    private static func readUInt16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        let low = UInt16(bytes[offset])
        let high = UInt16(bytes[offset + 1])
        return low | (high << 8)
    }

    private static func readUInt32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        let b0 = UInt32(bytes[offset])
        let b1 = UInt32(bytes[offset + 1])
        let b2 = UInt32(bytes[offset + 2])
        let b3 = UInt32(bytes[offset + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }
}

public func decodePage(_ bytes: Data) throws -> String {
    let headCount = min(800, bytes.count)
    let head = latin1(bytes.prefix(headCount))
    let isShiftJIS = containsMatch(head, pattern: "shift_jis|x-sjis|windows-31j", caseInsensitive: true)
    if !isShiftJIS {
        if let text = String(data: bytes, encoding: .utf8) { return text }
        return try ShiftJIS.decode(bytes)
    }
    let text = try ShiftJIS.decode(bytes)
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
