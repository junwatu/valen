import Foundation

public enum ControlConstants {
    public static let socketFileName = "valen-control.sock"
    public static let protocolVersion = 1

    public static var socketURL: URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(socketFileName)
    }
}

public enum ControlMethod: String, Codable, CaseIterable, Sendable {
    case play
    case pause
    case togglePlayPause
    case openFile = "open_file"
    case seek
    case setVolume = "set_volume"
    case setSpeed = "set_speed"
    case getState = "get_state"
}

public struct ControlRequest: Codable, Sendable {
    public let id: Int
    public let method: String
    public let params: [String: AnyCodable]?

    public init(id: Int, method: String, params: [String: AnyCodable]? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct ControlResponse: Codable, Sendable {
    public let id: Int
    public let result: AnyCodable?
    public let error: String?

    public init(id: Int, result: AnyCodable? = nil, error: String? = nil) {
        self.id = id
        self.result = result
        self.error = error
    }

    public static func ok(id: Int, result: AnyCodable? = nil) -> ControlResponse {
        ControlResponse(id: id, result: result ?? AnyCodable([String: String]()), error: nil)
    }

    public static func fail(id: Int, message: String) -> ControlResponse {
        ControlResponse(id: id, result: nil, error: message)
    }
}

public struct ControlState: Codable, Sendable {
    public let protocolVersion: Int
    public let currentFile: String?
    public let isPaused: Bool
    public let position: Double
    public let duration: Double
    public let volume: Double
    public let speed: Double

    public init(
        protocolVersion: Int = ControlConstants.protocolVersion,
        currentFile: String?,
        isPaused: Bool,
        position: Double,
        duration: Double,
        volume: Double,
        speed: Double
    ) {
        self.protocolVersion = protocolVersion
        self.currentFile = currentFile
        self.isPaused = isPaused
        self.position = position
        self.duration = duration
        self.volume = volume
        self.speed = speed
    }
}

public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map(\.value)
        } else if let object = try? container.decode([String: AnyCodable].self) {
            self.value = object.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int as Int64:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map(AnyCodable.init))
        case let dict as [String: Any]:
            try container.encode(dict.mapValues(AnyCodable.init))
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported value: \(type(of: value))"))
        }
    }

    public func string(for key: String) -> String? {
        guard let dict = value as? [String: Any], let raw = dict[key] else { return nil }
        if let s = raw as? String { return s }
        if let codable = raw as? AnyCodable, let s = codable.value as? String { return s }
        return nil
    }

    public func double(for key: String) -> Double? {
        guard let dict = value as? [String: Any], let raw = dict[key] else { return nil }
        if let n = raw as? Double { return n }
        if let i = raw as? Int { return Double(i) }
        if let codable = raw as? AnyCodable {
            if let n = codable.value as? Double { return n }
            if let i = codable.value as? Int { return Double(i) }
        }
        return nil
    }

    public func bool(for key: String) -> Bool? {
        guard let dict = value as? [String: Any], let raw = dict[key] else { return nil }
        if let b = raw as? Bool { return b }
        if let codable = raw as? AnyCodable, let b = codable.value as? Bool { return b }
        return nil
    }
}
