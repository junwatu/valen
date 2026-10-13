import Darwin
import Foundation

/// Restricts the Unix control socket to processes running as the same user.
public enum ControlSocketPeerPolicy {
    public static func isAuthorized(clientFD: Int32) -> Bool {
        var cred = xucred()
        var length = socklen_t(MemoryLayout<xucred>.size)
        let status = withUnsafeMutablePointer(to: &cred) { pointer in
            getsockopt(clientFD, SOL_LOCAL, LOCAL_PEERCRED, pointer, &length)
        }
        guard status == 0 else {
            return false
        }
        return cred.cr_uid == getuid()
    }
}
