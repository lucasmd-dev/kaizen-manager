import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var eventMonitor: Any?

    var serviceRunner: ProjectRunner?
    var mobRunner: ProjectRunner?
    var toolsRunner: ProjectRunner?

    private var cancellables = Set<AnyCancellable>()
    private var menuView: KaizenMenuView?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusItem()
        setupPanel()

        if ProjectRootManager.shared.rootPath != nil {
            initRunners()
        } else {
            ProjectRootManager.shared.promptForRootFolder { [weak self] confirmed in
                if confirmed { self?.initRunners() }
            }
        }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let imagePath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
               let customImage = NSImage(contentsOfFile: imagePath) {
                let maxSize: CGFloat = 20
                let originalSize = customImage.size
                let ratio = min(maxSize / originalSize.width, maxSize / originalSize.height)
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
    }

    private func setupPanel() {
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
    }

    private func initRunners() {
        guard
            let servicePath = ProjectRootManager.shared.path(for: "KS-Service"),
            let mobPath = ProjectRootManager.shared.path(for: "KS-Mob"),
            let toolsPath = ProjectRootManager.shared.path(for: "KS-Tools")
        else { return }

        let svc = ProjectRunner(
            name: "KS-Service",
            projectPath: servicePath,
            baseCommand: "mvn clean spring-boot:run",
            javaVersion: "17"
        )
        let mob = ProjectRunner(
            name: "KS-Mob",
            projectPath: mobPath,
            baseCommand: "npm run ionic:serve",
            nodeVersion: "12"
        )
        let tools = ProjectRunner(
            name: "KS-Tools",
            projectPath: toolsPath,
            baseCommand: "npm start",
            nodeVersion: "16"
        )

        serviceRunner = svc
        mobRunner = mob
        toolsRunner = tools

        let view = KaizenMenuView(
            serviceRunner: svc,
            mobRunner: mob,
            toolsRunner: tools,
            quitAction: { [weak self] in self?.quitApp() },
            startAllAction: { [weak self] in self?.startAll() },
            stopAllAction: { [weak self] in self?.stopAll() },
            changeFolderAction: { [weak self] in self?.changeFolder() }
        )
        menuView = view

        let hostingView = NSHostingView(rootView: view)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView

        Publishers.CombineLatest3(svc.$status, mob.$status, tools.$status)
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

    // MARK: - Panel

    @objc func togglePanel(_ sender: AnyObject?) {
        if panel.isVisible { hidePanel() } else { showPanel() }
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

    // MARK: - Actions

    func startAll() {
        serviceRunner?.start()
        mobRunner?.start()
        toolsRunner?.start()
    }

    func stopAll() {
        serviceRunner?.stop()
        mobRunner?.stop()
        toolsRunner?.stop()
    }

    func changeFolder() {
        hidePanel()
        stopAll()
        ProjectRootManager.shared.promptForRootFolder { [weak self] confirmed in
            if confirmed {
                self?.cancellables.removeAll()
                self?.initRunners()
            }
        }
    }

    func quitApp() {
        stopAll()
        NSApplication.shared.terminate(self)
    }
}
