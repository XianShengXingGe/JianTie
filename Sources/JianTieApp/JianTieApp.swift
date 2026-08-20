//  JianTie - macOS shelf & clipboard assistant
//  https://github.com/XianShengXingGe/JianTie

import Cocoa

@main
@MainActor
final class JianTieApp {
    static func main() {
        ProcessInfo.processInfo.processName = "简贴"
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
