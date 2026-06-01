import AppKit
import Foundation

struct AppInfo {
    let name: String
    let description: String
    let version: String
    let build: String
    let creatorName: String
    let creatorURL: URL
    let year: String

    static var current: AppInfo {
        let bundleInfo = Bundle.main.infoDictionary ?? [:]
        let name = bundleInfo["CFBundleDisplayName"] as? String
            ?? bundleInfo["CFBundleName"] as? String
            ?? "Valen"
        let version = bundleInfo["CFBundleShortVersionString"] as? String ?? "Development"
        let build = bundleInfo["CFBundleVersion"] as? String ?? "local"
        let year = String(Calendar.current.component(.year, from: Date()))

        return AppInfo(
            name: name,
            description: "A native macOS media player powered by mpv.",
            version: version,
            build: build,
            creatorName: "@junwatu",
            creatorURL: URL(string: "https://x.com/junwatu")!,
            year: year
        )
    }
}

enum AboutPanelPresenter {
    @MainActor
    static func show() {
        let info = AppInfo.current
        let credits = NSMutableAttributedString(
            string: "\(info.description)\n\nCreated by \(info.creatorName)\n\(info.creatorURL.absoluteString)\n\nCopyright \(info.year)",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        let fullText = credits.string as NSString
        let urlRange = fullText.range(of: info.creatorURL.absoluteString)
        if urlRange.location != NSNotFound {
            credits.addAttributes(
                [
                    .link: info.creatorURL,
                    .foregroundColor: NSColor.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ],
                range: urlRange
            )
        }

        NSApp.orderFrontStandardAboutPanel(
            options: [
                .applicationName: info.name,
                .applicationVersion: "\(info.version) (\(info.build))",
                .version: "Version \(info.version)",
                .credits: credits
            ]
        )
    }
}
