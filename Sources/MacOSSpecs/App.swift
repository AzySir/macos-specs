import AppKit

@main
enum MacOSSpecsApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var sampler: MetricsSampler?
    private var settings: AppSettings?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerLoginItemIfFirstLaunch()

        let settings = AppSettings()
        let sampler = MetricsSampler()
        let menuBar = MenuBarController(sampler: sampler, settings: settings)
        sampler.start(interval: settings.refreshInterval)
        self.settings = settings
        self.sampler = sampler
        self.menuBar = menuBar
    }

    private func registerLoginItemIfFirstLaunch() {
        let defaults = UserDefaults.standard
        let key = "firstLaunchHandled"
        guard defaults.object(forKey: key) == nil else { return }
        LoginItem.setEnabled(true)
        defaults.set(true, forKey: key)
    }


    func applicationWillTerminate(_ notification: Notification) {
        sampler?.stop()
    }
}
