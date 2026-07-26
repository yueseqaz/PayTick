import AppKit

@main
enum WorkClockApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // 隐藏 Dock 图标（菜单栏专用 App）
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
