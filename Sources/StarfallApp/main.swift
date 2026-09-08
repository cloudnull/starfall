import AppKit
import StarfallCore
import StarfallMelee

/// Application entry point for Starfall.
final class StarfallAppDelegate: NSObject, NSApplicationDelegate {
    private var gameController: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        
        let arena = ArenaState(
            bounds: Rect(min: Vec2(x: -400, y: -300), max: Vec2(x: 400, y: 300)),
            planetPosition: Vec2.zero,
            planetRadius: 50,
            gravityStrength: 18_000
        )

        gameController = GameController(arena: arena)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Preferences action (Command-comma) — opens the Settings scene.
    @objc @MainActor private func showPreferences() {
        (gameController as? GameController)?.showSettings()
    }

    /// Build the standard macOS menu bar with proper keyboard shortcuts.
    @MainActor private func setupMenuBar() {
        let appName = "Starfall"
        
        // --- App menu ---
        let appMenu = NSMenu(title: appName)
        
        var menuItem = NSMenuItem(title: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menuItem.tag = 0
        appMenu.addItem(menuItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Services submenu
        let servicesMenu = NSMenu()
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        menuItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        appMenu.addItem(menuItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        menuItem = NSMenuItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(menuItem)
        
        menuItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        menuItem.keyEquivalentModifierMask = [.command, .shift]
        appMenu.addItem(menuItem)
        
        menuItem = NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(menuItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        menuItem = NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(menuItem)
        
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        NSApp.mainMenu?.addItem(appMenuItem)
        
        // --- Window menu ---
        let windowMenu = NSMenu(title: "Window")
        
        menuItem = NSMenuItem(title: "Minimize", action: Selector(("_performMiniaturize:")), keyEquivalent: "m")
        windowMenu.addItem(menuItem)
        
        menuItem = NSMenuItem(title: "Zoom", action: Selector(("_performZoom:")), keyEquivalent: "")
        windowMenu.addItem(menuItem)
        
        windowMenu.addItem(NSMenuItem.separator())
        
        menuItem = NSMenuItem(title: "Bring All to Front", action: Selector(("_arrangeInFront:")), keyEquivalent: "")
        windowMenu.addItem(menuItem)
        
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        NSApp.mainMenu?.addItem(windowMenuItem)
    }
}

let appDelegate = StarfallAppDelegate()
let app = NSApplication.shared
app.delegate = appDelegate
app.run()
