import Foundation

/// Supported request/response payload encodings.
public enum PayloadEncoding: Sendable {
    case json
    case cbor
}

enum PayloadCodec {
    static func encode<T: Encodable>(
        _ value: T,
        as encoding: PayloadEncoding,
        using encoder: JSONEncoder
    ) throws -> Data {
        let jsonData = try encoder.encode(value)
        guard encoding == .cbor else {
            return jsonData
        }

        let object = try JSONSerialization.jsonObject(with: jsonData)
        return try MiniCBOR.encode(object)
    }

    static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        preferred encoding: PayloadEncoding,
        using decoder: JSONDecoder
    ) throws -> T {
        switch encoding {
        case .json:
            return try decoder.decode(type, from: data)
        case .cbor:
            do {
                let object = try MiniCBOR.decode(data)
                let jsonData = try JSONSerialization.data(withJSONObject: object)
                return try decoder.decode(type, from: jsonData)
            } catch {
                // Allow graceful fallback when server responds with JSON
                return try decoder.decode(type, from: data)
            }
        }
    }
}

private enum MiniCBORError: Error {
    case unsupportedType(String)
    case invalidData
    case outOfBounds
    case unsupportedSimpleValue(UInt8)
}

private enum MiniCBOR {
    static func encode(_ value: Any) throws -> Data {
        var data = Data()
        try encodeValue(value, into: &data)
        return data
    }

    static func decode(_ data: Data) throws -> Any {
        var cursor = data.startIndex
        let decoded = try decodeValue(data, cursor: &cursor)
        return decoded
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func encodeValue(_ value: Any, into data: inout Data) throws {
        switch value {
        case is NSNull:
            data.append(0xF6)
        case let value as Bool:
            data.append(value ? 0xF5 : 0xF4)
        case let value as Int:
            try encodeInteger(value, into: &data)
        case let value as Int64:
            try encodeInteger(Int(value), into: &data)
        case let value as UInt:
            try encodeUnsigned(value, majorType: 0, into: &data)
        case let value as UInt64:
            try encodeUnsigned(value, majorType: 0, into: &data)
        case let value as Double:
            data.append(0xFB)
            var bits = value.bitPattern.bigEndian
            withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
        case let value as Float:
            try encodeValue(Double(value), into: &data)
        case let value as String:
            let bytes = Data(value.utf8)
            try encodeUnsigned(UInt64(bytes.count), majorType: 3, into: &data)
            data.append(bytes)
        case let value as [Any]:
            try encodeUnsigned(UInt64(value.count), majorType: 4, into: &data)
            for item in value {
                try encodeValue(item, into: &data)
            }
        case let value as [String: Any]:
            try encodeUnsigned(UInt64(value.count), majorType: 5, into: &data)
            for key in value.keys.sorted() {
                try encodeValue(key, into: &data)
                if let entry = value[key] {
                    try encodeValue(entry, into: &data)
                } else {
                    data.append(0xF6)
                }
            }
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                try encodeValue(value.boolValue, into: &data)
            } else {
                try encodeValue(value.doubleValue, into: &data)
            }
        default:
            throw MiniCBORError.unsupportedType(String(describing: type(of: value)))
        }
    }

    private static func encodeInteger(_ value: Int, into data: inout Data) throws {
        if value >= 0 {
            try encodeUnsigned(UInt64(value), majorType: 0, into: &data)
            return
        }

        let encoded = UInt64(-1 - value)
        try encodeUnsigned(encoded, majorType: 1, into: &data)
    }

    private static func encodeUnsigned(_ value: UInt, majorType: UInt8, into data: inout Data) throws {
        try encodeUnsigned(UInt64(value), majorType: majorType, into: &data)
    }

    private static func encodeUnsigned(_ value: UInt64, majorType: UInt8, into data: inout Data) throws {
        let head = majorType << 5
        switch value {
        case 0...23:
            data.append(head | UInt8(value))
        case 24...0xFF:
            data.append(head | 24)
            data.append(UInt8(value))
        case 0x100...0xFFFF:
            data.append(head | 25)
            var value16 = UInt16(value).bigEndian
            withUnsafeBytes(of: &value16) { data.append(contentsOf: $0) }
        case 0x1_0000...0xFFFF_FFFF:
            data.append(head | 26)
            var value32 = UInt32(value).bigEndian
            withUnsafeBytes(of: &value32) { data.append(contentsOf: $0) }
        default:
            data.append(head | 27)
            var value64 = value.bigEndian
            withUnsafeBytes(of: &value64) { data.append(contentsOf: $0) }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func decodeValue(_ data: Data, cursor: inout Data.Index) throws -> Any {
        guard cursor < data.endIndex else {
            throw MiniCBORError.outOfBounds
        }

        let initial = data[cursor]
        cursor = data.index(after: cursor)

        let majorType = initial >> 5
        let additional = initial & 0x1F

        switch majorType {
        case 0:
            return try readLength(additional, data: data, cursor: &cursor)
        case 1:
            let negativeInt = try readLength(additional, data: data, cursor: &cursor)
            return -1 - Int(negativeInt)
        case 2:
            let length = Int(try readLength(additional, data: data, cursor: &cursor))
            return try readData(length: length, data: data, cursor: &cursor)
        case 3:
            let length = Int(try readLength(additional, data: data, cursor: &cursor))
            let bytes = try readData(length: length, data: data, cursor: &cursor)
            guard let string = String(data: bytes, encoding: .utf8) else {
                throw MiniCBORError.invalidData
            }
            return string
        case 4:
            let count = Int(try readLength(additional, data: data, cursor: &cursor))
            var values: [Any] = []
            values.reserveCapacity(count)
            for _ in 0..<count {
                values.append(try decodeValue(data, cursor: &cursor))
            }
            return values
        case 5:
            let count = Int(try readLength(additional, data: data, cursor: &cursor))
            var values: [String: Any] = [:]
            for _ in 0..<count {
                let keyValue = try decodeValue(data, cursor: &cursor)
                guard let key = keyValue as? String else {
                    throw MiniCBORError.invalidData
                }
                values[key] = try decodeValue(data, cursor: &cursor)
            }
            return values
        case 7:
            switch additional {
            case 20:
                return false
            case 21:
                return true
            case 22:
                return NSNull()
            case 27:
                let value = try readUInt64(data: data, cursor: &cursor)
                return Double(bitPattern: value)
            default:
                throw MiniCBORError.unsupportedSimpleValue(additional)
            }
        default:
            throw MiniCBORError.invalidData
        }
    }

    private static func readLength(
        _ additional: UInt8,
        data: Data,
        cursor: inout Data.Index
    ) throws -> UInt64 {
        switch additional {
        case 0...23:
            return UInt64(additional)
        case 24:
            return UInt64(try readUInt8(data: data, cursor: &cursor))
        case 25:
            return UInt64(try readUInt16(data: data, cursor: &cursor))
        case 26:
            return UInt64(try readUInt32(data: data, cursor: &cursor))
        case 27:
            return try readUInt64(data: data, cursor: &cursor)
        default:
            throw MiniCBORError.invalidData
        }
    }

    private static func readData(length: Int, data: Data, cursor: inout Data.Index) throws -> Data {
        guard length >= 0 else { throw MiniCBORError.invalidData }
        guard data.distance(from: cursor, to: data.endIndex) >= length else {
            throw MiniCBORError.outOfBounds
        }
        let end = data.index(cursor, offsetBy: length)
        let slice = data[cursor..<end]
        cursor = end
        return Data(slice)
    }

    private static func readUInt8(data: Data, cursor: inout Data.Index) throws -> UInt8 {
        guard cursor < data.endIndex else { throw MiniCBORError.outOfBounds }
        let value = data[cursor]
        cursor = data.index(after: cursor)
        return value
    }

    private static func readUInt16(data: Data, cursor: inout Data.Index) throws -> UInt16 {
        let bytes = try readData(length: 2, data: data, cursor: &cursor)
        return bytes.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
    }

    private static func readUInt32(data: Data, cursor: inout Data.Index) throws -> UInt32 {
        let bytes = try readData(length: 4, data: data, cursor: &cursor)
        return bytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }

    private static func readUInt64(data: Data, cursor: inout Data.Index) throws -> UInt64 {
        let bytes = try readData(length: 8, data: data, cursor: &cursor)
        return bytes.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
    }
}
