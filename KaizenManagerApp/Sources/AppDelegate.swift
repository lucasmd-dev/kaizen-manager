import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var eventMonitor: Any?

    var serviceRunner: ProjectRunner!
    var mobRunner: ProjectRunner!
    var toolsRunner: ProjectRunner!

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        serviceRunner = ProjectRunner(
            name: "KS-Service",
            projectPath: "/Users/lucas/Documents/Kaizen/Kaizen/KS-Service",
            baseCommand: "mvn clean spring-boot:run",
            javaVersion: "17"
        )

        mobRunner = ProjectRunner(
            name: "KS-Mob",
            projectPath: "/Users/lucas/Documents/Kaizen/Kaizen/KS-Mob",
            baseCommand: "npm run ionic:serve",
            nodeVersion: "12"
        )

        toolsRunner = ProjectRunner(
            name: "KS-Tools",
            projectPath: "/Users/lucas/Documents/Kaizen/Kaizen/KS-Tools",
            baseCommand: "npm start",
            nodeVersion: "16"
        )

        let menuView = KaizenMenuView(
            serviceRunner: serviceRunner,
            mobRunner: mobRunner,
            toolsRunner: toolsRunner,
            quitAction: { [weak self] in self?.quitApp() },
            startAllAction: { [weak self] in self?.startAll() },
            stopAllAction: { [weak self] in self?.stopAll() }
        )

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 260),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let hostingView = NSHostingView(rootView: menuView)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let imagePath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
               let customImage = NSImage(contentsOfFile: imagePath) {
                let maxWidth: CGFloat = 20
                let maxHeight: CGFloat = 20
                let originalSize = customImage.size
                let ratio = min(maxWidth / originalSize.width, maxHeight / originalSize.height)
                customImage.size = NSSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
                customImage.isTemplate = false
                button.image = customImage
            } else {
                let config = NSImage.SymbolConfiguration(hierarchicalColor: .white)
                let image = NSImage(systemSymbolName: "k.circle.fill", accessibilityDescription: "Kaizen Manager")?.withSymbolConfiguration(config)
                image?.isTemplate = false
                button.image = image
                button.contentTintColor = nil
            }
            button.action = #selector(togglePanel(_:))
            button.target = self
        }

        Publishers.CombineLatest3(serviceRunner.$status, mobRunner.$status, toolsRunner.$status)
            .receive(on: RunLoop.main)
            .sink { _ in }
            .store(in: &cancellables)

        // Show password prompt as key window so SecureField accepts keyboard input
        PasswordManager.shared.$showPasswordPrompt
            .receive(on: RunLoop.main)
            .sink { [weak self] showing in
                guard let self = self else { return }
                if showing {
                    self.panel.styleMask.insert(.titled)
                    self.panel.styleMask.remove(.nonactivatingPanel)
                    self.panel.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                } else {
                    self.panel.styleMask.remove(.titled)
                    self.panel.styleMask.insert(.nonactivatingPanel)
                }
            }
            .store(in: &cancellables)
    }

    @objc func togglePanel(_ sender: AnyObject?) {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        if let button = statusItem.button, let window = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = window.convertToScreen(buttonRect)

            let panelWidth: CGFloat = 230
            let panelHeight: CGFloat = panel.contentView?.fittingSize.height ?? 260

            let x = screenRect.minX - 4
            let y = screenRect.minY - panelHeight - 2

            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.hidePanel()
            }
        }
    }

    func hidePanel() {
        panel.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func startAll() {
        serviceRunner.start()
        mobRunner.start()
        toolsRunner.start()
    }

    func stopAll() {
        serviceRunner.stop()
        mobRunner.stop()
        toolsRunner.stop()
    }

    func quitApp() {
        serviceRunner.stop()
        mobRunner.stop()
        toolsRunner.stop()
        NSApplication.shared.terminate(self)
    }
}
