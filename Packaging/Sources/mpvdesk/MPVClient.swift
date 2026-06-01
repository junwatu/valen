import AppKit
import CMpv
import Foundation
import OpenGL.GL3
import Darwin

enum MPVError: LocalizedError {
    case createFailed
    case commandFailed(String)
    case setPropertyFailed(String)
    case renderContextFailed(String)

    var errorDescription: String? {
        switch self {
        case .createFailed:
            return "Could not create an mpv client."
        case .commandFailed(let message):
            return "mpv command failed: \(message)"
        case .setPropertyFailed(let name):
            return "Could not set mpv property: \(name)"
        case .renderContextFailed(let message):
            return "Could not create mpv render context: \(message)"
        }
    }
}

@MainActor
final class MPVClient {
    private var handle: OpaquePointer?
    private var renderContext: OpaquePointer?
    private weak var renderTarget: (any VideoRenderSurface)?

    func initialize() throws {
        guard handle == nil else { return }
        guard let created = mpv_create() else {
            throw MPVError.createFailed
        }

        handle = created
        try setString("terminal", value: "no")
        try setString("msg-level", value: "all=v")
        try setString("vo", value: "libmpv")

        let status = mpv_initialize(created)
        guard status >= 0 else {
            throw MPVError.commandFailed(errorString(status))
        }

        mpv_request_log_messages(created, "v")
    }

    func attachDrawable(_ view: MPVHostView) {
        view.configure(mpv: self)
    }

    func attachRenderTarget(_ view: MPVHostView) throws {
        guard let handle else { throw MPVError.createFailed }
        guard renderContext == nil else {
            renderTarget = view
            return
        }

        renderTarget = view

        var initParams = mpv_opengl_init_params(
            get_proc_address: mpvGetOpenGLProcAddress,
            get_proc_address_ctx: nil
        )

        var context: OpaquePointer?
        var apiType = Array("opengl".utf8CString)
        let status = apiType.withUnsafeMutableBufferPointer { apiBuffer in
            withUnsafeMutablePointer(to: &initParams) { initPointer in
                var params = [
                    mpv_render_param(
                        type: MPV_RENDER_PARAM_API_TYPE,
                        data: UnsafeMutableRawPointer(apiBuffer.baseAddress)
                    ),
                    mpv_render_param(
                        type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS,
                        data: UnsafeMutableRawPointer(initPointer)
                    ),
                    mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
                ]

                return params.withUnsafeMutableBufferPointer { buffer in
                    mpv_render_context_create(&context, handle, buffer.baseAddress)
                }
            }
        }

        guard status >= 0, let context else {
            throw MPVError.renderContextFailed(errorString(status))
        }

        renderContext = context
        mpv_render_context_set_update_callback(
            context,
            mpvRenderUpdateCallback,
            Unmanaged.passUnretained(view).toOpaque()
        )
    }

    func detachRenderTarget(_ view: MPVHostView) {
        guard renderTarget === view else { return }
        if let renderContext {
            mpv_render_context_set_update_callback(renderContext, nil, nil)
            mpv_render_context_free(renderContext)
            self.renderContext = nil
        }
        renderTarget = nil
    }

    func render(width: Int, height: Int) -> Bool {
        guard let renderContext else { return false }

        let updateFlags = mpv_render_context_update(renderContext)
        guard updateFlags & UInt64(MPV_RENDER_UPDATE_FRAME.rawValue) != 0 else {
            return false
        }

        var fbo = mpv_opengl_fbo(
            fbo: 0,
            w: Int32(width),
            h: Int32(height),
            internal_format: Int32(GL_RGBA8)
        )
        var flipY: Int32 = 1

        var params: [mpv_render_param] = [
            mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: nil),
            mpv_render_param(type: MPV_RENDER_PARAM_FLIP_Y, data: nil),
            mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
        ]

        withUnsafeMutablePointer(to: &fbo) { fboPointer in
            withUnsafeMutablePointer(to: &flipY) { flipPointer in
                params[0].data = UnsafeMutableRawPointer(fboPointer)
                params[1].data = UnsafeMutableRawPointer(flipPointer)
                params.withUnsafeMutableBufferPointer { buffer in
                    _ = mpv_render_context_render(renderContext, buffer.baseAddress)
                }
            }
        }

        return true
    }

    func reportSwap() {
        guard let renderContext else { return }
        mpv_render_context_report_swap(renderContext)
    }

    func command(_ args: [String]) throws {
        guard let handle else { throw MPVError.createFailed }
        NSLog("[valen] command: \(args.joined(separator: " "))")

        let cStrings: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        defer {
            for pointer in cStrings {
                if let pointer {
                    free(pointer)
                }
            }
        }

        var command: [UnsafePointer<CChar>?] = cStrings.map { ptr in
            ptr.map { UnsafePointer<CChar>($0) }
        }
        command.append(nil)

        let status = command.withUnsafeMutableBufferPointer { buffer in
            mpv_command(handle, buffer.baseAddress)
        }

        guard status >= 0 else {
            throw MPVError.commandFailed(errorString(status))
        }
    }

    func setString(_ name: String, value: String) throws {
        guard let handle else { throw MPVError.createFailed }
        NSLog("[valen] set \(name)=\(value)")
        let status = value.withCString { pointer in
            mpv_set_property_string(handle, name, pointer)
        }

        guard status >= 0 else {
            throw MPVError.setPropertyFailed(name)
        }
    }

    func setFlag(_ name: String, value: Bool) throws {
        var intValue: Int32 = value ? 1 : 0
        guard let handle else { throw MPVError.createFailed }
        NSLog("[valen] set \(name)=\(value)")
        let status = mpv_set_property(handle, name, MPV_FORMAT_FLAG, &intValue)
        guard status >= 0 else {
            throw MPVError.setPropertyFailed(name)
        }
    }

    func setDouble(_ name: String, value: Double) throws {
        var doubleValue = value
        guard let handle else { throw MPVError.createFailed }
        NSLog("[valen] set \(name)=\(value)")
        let status = mpv_set_property(handle, name, MPV_FORMAT_DOUBLE, &doubleValue)
        guard status >= 0 else {
            throw MPVError.setPropertyFailed(name)
        }
    }

    func setInt(_ name: String, value: Int) throws {
        var intValue = Int64(value)
        guard let handle else { throw MPVError.createFailed }
        NSLog("[valen] set \(name)=\(value)")
        let status = mpv_set_property(handle, name, MPV_FORMAT_INT64, &intValue)
        guard status >= 0 else {
            throw MPVError.setPropertyFailed(name)
        }
    }

    func getFlag(_ name: String) -> Bool? {
        var value: Int32 = 0
        guard let handle, mpv_get_property(handle, name, MPV_FORMAT_FLAG, &value) >= 0 else {
            return nil
        }
        return value != 0
    }

    func getDouble(_ name: String) -> Double? {
        var value: Double = 0
        guard let handle, mpv_get_property(handle, name, MPV_FORMAT_DOUBLE, &value) >= 0 else {
            return nil
        }
        return value
    }

    func getInt(_ name: String) -> Int? {
        var value: Int64 = 0
        guard let handle, mpv_get_property(handle, name, MPV_FORMAT_INT64, &value) >= 0 else {
            return nil
        }
        return Int(value)
    }

    func getString(_ name: String) -> String? {
        guard let handle, let value = mpv_get_property_string(handle, name) else {
            return nil
        }
        defer { mpv_free(value) }
        return String(cString: value)
    }

    func getTracks() -> [MediaTrack] {
        guard let count = getInt("track-list/count"), count > 0 else {
            return []
        }

        var tracks: [MediaTrack] = []

        for index in 0..<count {
            guard let type = getString("track-list/\(index)/type"),
                  let id = getInt("track-list/\(index)/id") else {
                continue
            }

            let kind: MediaTrackKind
            switch type {
            case "audio":
                kind = .audio
            case "sub":
                kind = .subtitle
            default:
                continue
            }

            tracks.append(
                MediaTrack(
                    id: id,
                    kind: kind,
                    title: getString("track-list/\(index)/title"),
                    language: getString("track-list/\(index)/lang"),
                    codec: getString("track-list/\(index)/codec"),
                    isDefault: getFlag("track-list/\(index)/default") ?? false,
                    isForced: getFlag("track-list/\(index)/forced") ?? false,
                    isSelected: getFlag("track-list/\(index)/selected") ?? false
                )
            )
        }

        return tracks
    }

    func drainEvents() -> [String] {
        guard let handle else { return [] }

        var lines: [String] = []

        while true {
            guard let event = mpv_wait_event(handle, 0) else { break }
            let eventID = event.pointee.event_id
            guard eventID != MPV_EVENT_NONE else { break }

            if eventID == MPV_EVENT_LOG_MESSAGE,
               let data = event.pointee.data {
                let message = data.assumingMemoryBound(to: mpv_event_log_message.self).pointee
                let prefix = message.prefix.map { String(cString: $0) } ?? "mpv"
                let level = message.level.map { String(cString: $0) } ?? "info"
                let text = message.text.map { String(cString: $0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
                lines.append("[mpv:\(level):\(prefix)] \(text)")
            } else {
                let name = mpv_event_name(eventID).map { String(cString: $0) } ?? "event-\(eventID.rawValue)"
                if event.pointee.error < 0 {
                    lines.append("[mpv:event] \(name) error=\(errorString(event.pointee.error))")
                } else {
                    lines.append("[mpv:event] \(name)")
                }
            }
        }

        return lines
    }

    func subtitleDiagnostics() -> String {
        let sid = getString("sid") ?? "nil"
        let secondarySid = getString("secondary-sid") ?? "nil"
        let subVisibility = getString("sub-visibility") ?? "nil"
        let subAss = getString("sub-ass") ?? "nil"
        let embeddedFonts = getString("embeddedfonts") ?? "nil"
        let subText = getString("sub-text") ?? ""
        let osdDimensions = getString("osd-dimensions") ?? "nil"
        return "sid=\(sid), secondary-sid=\(secondarySid), sub-visibility=\(subVisibility), sub-ass=\(subAss), embeddedfonts=\(embeddedFonts), osd=\(osdDimensions), sub-text=\(subText.debugDescription)"
    }

    private func errorString(_ status: Int32) -> String {
        guard let message = mpv_error_string(status) else {
            return "unknown error \(status)"
        }
        return String(cString: message)
    }
}

private func mpvGetOpenGLProcAddress(
    _ ctx: UnsafeMutableRawPointer?,
    _ name: UnsafePointer<CChar>?
) -> UnsafeMutableRawPointer? {
    guard let name else { return nil }
    let openGL = dlopen("/System/Library/Frameworks/OpenGL.framework/OpenGL", RTLD_LAZY)
    return dlsym(openGL, name)
}

private func mpvRenderUpdateCallback(_ ctx: UnsafeMutableRawPointer?) {
    guard let ctx else { return }
    let address = UInt(bitPattern: ctx)
    DispatchQueue.main.async {
        guard let ctx = UnsafeMutableRawPointer(bitPattern: address) else { return }
        let view = Unmanaged<MPVHostView>.fromOpaque(ctx).takeUnretainedValue()
        view.scheduleRender()
    }
}
