import AppKit
import CMpv
import OpenGL.GL3
import SwiftUI

@MainActor
protocol VideoRenderSurface: AnyObject {
    func scheduleRender()
}

struct VideoSurfaceView: NSViewRepresentable {
    @EnvironmentObject private var player: PlayerModel

    func makeNSView(context: Context) -> MPVHostView {
        let view = MPVHostView()
        player.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: MPVHostView, context: Context) {
        player.attach(to: nsView)
    }
}

final class MPVHostView: NSOpenGLView, VideoRenderSurface {
    private weak var mpv: MPVClient?
    private var didPrepareMpv = false

    init() {
        let attributes: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAAccelerated),
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAOpenGLProfile),
            UInt32(NSOpenGLProfileVersion3_2Core),
            UInt32(NSOpenGLPFAColorSize), 24,
            UInt32(NSOpenGLPFAAlphaSize), 8,
            UInt32(NSOpenGLPFADepthSize), 0,
            UInt32(NSOpenGLPFAStencilSize), 0,
            0
        ]

        let pixelFormat = NSOpenGLPixelFormat(attributes: attributes)
        super.init(frame: .zero, pixelFormat: pixelFormat)!
        wantsBestResolutionOpenGLSurface = true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsBestResolutionOpenGLSurface = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsBestResolutionOpenGLSurface = true
    }

    func configure(mpv: MPVClient) {
        guard self.mpv !== mpv else { return }
        self.mpv = mpv
        prepareMpvIfNeeded()
    }

    override func prepareOpenGL() {
        super.prepareOpenGL()
        openGLContext?.makeCurrentContext()

        var swapInterval: GLint = 1
        openGLContext?.setValues(&swapInterval, for: .swapInterval)
        prepareMpvIfNeeded()
    }

    override func reshape() {
        super.reshape()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        openGLContext?.makeCurrentContext()

        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let width = max(1, Int(bounds.width * scale))
        let height = max(1, Int(bounds.height * scale))

        glViewport(0, 0, GLsizei(width), GLsizei(height))
        glClearColor(0, 0, 0, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        let didRender = mpv?.render(width: width, height: height) ?? false
        openGLContext?.flushBuffer()
        if didRender {
            mpv?.reportSwap()
        }
    }

    func scheduleRender() {
        DispatchQueue.main.async { [weak self] in
            self?.needsDisplay = true
        }
    }

    private func prepareMpvIfNeeded() {
        guard !didPrepareMpv, let mpv, openGLContext != nil else { return }
        openGLContext?.makeCurrentContext()

        do {
            try mpv.attachRenderTarget(self)
            didPrepareMpv = true
        } catch {
            NSLog("mpv render context failed: \(error.localizedDescription)")
        }
    }
}
