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
    var controlRunner: ProjectRunner!

    private var cancellables = Set<AnyCancellable>()

    // Projects that still need a folder assigned on first launch
    private let projectNames = ["KS-Service", "KS-Mob", "KS-Tools", "Control"]

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Runners are created with a placeholder path; stored path is loaded in init
        serviceRunner = ProjectRunner(
            name: "KS-Service",
            projectPath: "",
            baseCommand: "mvn spring-boot:run",
            javaVersion: "17",
            startedKeyword: "Started ServiceApplication"
        )
        mobRunner = ProjectRunner(
            name: "KS-Mob",
            projectPath: "",
            baseCommand: "sh -c '[ -d node_modules ] || npm install && npm run ionic:serve'",
            nodeVersion: "12"
        )
        toolsRunner = ProjectRunner(
            name: "KS-Tools",
            projectPath: "",
            baseCommand: "sh -c '[ -d node_modules ] || npm install && npm start'",
            nodeVersion: "16"
        )
        controlRunner = ProjectRunner(
            name: "Control",
            projectPath: "/Users/lucas/Documents/Projetos Pessoais/remote control/panel",
            baseCommand: "npm run dev",
            nodeVersion: "24.14.1"
        )

        setupStatusItem()
        setupPanel()
        subscribeToRunnerState()

        let missing = projectNames.filter { ProjectRootManager.shared.path(for: $0) == nil }
        if missing.isEmpty {
            applyStoredPaths()
        } else {
            promptSequentially(names: missing, index: 0) { [weak self] in
                self?.applyStoredPaths()
            }
        }
    }

    // MARK: - Path helpers

    private func applyStoredPaths() {
        if let p = ProjectRootManager.shared.path(for: "KS-Service") { serviceRunner.projectPath = p }
        if let p = ProjectRootManager.shared.path(for: "KS-Mob")     { mobRunner.projectPath = p }
        if let p = ProjectRootManager.shared.path(for: "KS-Tools")   { toolsRunner.projectPath = p }
        if let p = ProjectRootManager.shared.path(for: "Control") { controlRunner.projectPath = p }
    }

    /// Asks the user to pick a folder for each project in `names`, one at a time.
    private func promptSequentially(names: [String], index: Int, completion: @escaping () -> Void) {
        guard index < names.count else { completion(); return }
        ProjectRootManager.shared.promptForPath(projectName: names[index]) { [weak self] _ in
            self?.promptSequentially(names: names, index: index + 1, completion: completion)
        }
    }

    func changeFolder(for runner: ProjectRunner) {
        runner.stop()
        ProjectRootManager.shared.promptForPath(projectName: runner.name) { path in
            if let path = path { runner.projectPath = path }
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
        let menuView = KaizenMenuView(
            serviceRunner: serviceRunner,
            mobRunner: mobRunner,
            toolsRunner: toolsRunner,
            controlRunner: controlRunner,
            quitAction: { [weak self] in self?.quitApp() },
            startAllAction: { [weak self] in self?.startAll() },
            stopAllAction: { [weak self] in self?.stopAll() },
            changeFolderAction: { [weak self] runner in self?.changeFolder(for: runner) }
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
    }

    private func subscribeToRunnerState() {
        Publishers.CombineLatest4(serviceRunner.$status, mobRunner.$status, toolsRunner.$status, controlRunner.$status)
            .receive(on: RunLoop.main)
            .sink { _ in }
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
        serviceRunner.start()
        mobRunner.start()
        toolsRunner.start()
        controlRunner.start()
    }

    func stopAll() {
        serviceRunner.stop()
        mobRunner.stop()
        toolsRunner.stop()
        controlRunner.stop()
    }

    func quitApp() {
        stopAll()
        NSApplication.shared.terminate(self)
    }
}
