import Foundation

public enum ControlCommandPolicy {
    public static let minimumVolume = 0.0
    public static let maximumVolume = 150.0
    public static let minimumSpeed = 0.25
    public static let maximumSpeed = 4.0

    public static func validOpenPath(_ path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return nil
        }
        return path
    }

    public static func clampVolume(_ value: Double) -> Double {
        max(minimumVolume, min(value, maximumVolume))
    }

    public static func clampSpeed(_ value: Double) -> Double {
        max(minimumSpeed, min(value, maximumSpeed))
    }
}
