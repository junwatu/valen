import Foundation
import SwiftUI

#if canImport(Sparkle)
import Sparkle

final class SparkleUpdaterController: NSObject, ObservableObject {
    let isAvailable = true
    private let updaterController: SPUStandardUpdaterController

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
#else
final class SparkleUpdaterController: ObservableObject {
    let isAvailable = false

    func checkForUpdates() {}
}
#endif
