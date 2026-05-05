import Foundation
import Combine
import AppKit

enum ProjectStatus {
    case stopped
    case starting
    case running
    case error
}

class ProjectRunner: ObservableObject {
    let name: String
    let baseCommand: String
    /// When set, the status only moves to .running once this keyword appears in stdout.
    /// When nil, any output marks the process as running.
    let startedKeyword: String?

    // Mutable so the user can change the folder at runtime
    @Published var projectPath: String {
        didSet {
            UserDefaults.standard.set(projectPath, forKey: "\(name)_Path")
            gitMonitor = GitMonitor(projectPath: projectPath)
        }
    }

    @Published var nodeVersion: String? {
        didSet { UserDefaults.standard.set(nodeVersion, forKey: "\(name)_Node") }
    }

    @Published var javaVersion: String? {
        didSet { UserDefaults.standard.set(javaVersion, forKey: "\(name)_Java") }
    }

    private var process: Process?
    private var isIntentionallyStopped = false

    @Published var status: ProjectStatus = .stopped
    @Published var gitMonitor: GitMonitor
    @Published var lastError: String = ""

    init(name: String, projectPath: String, baseCommand: String,
         nodeVersion: String? = nil, javaVersion: String? = nil,
         startedKeyword: String? = nil) {
        self.name = name
        self.baseCommand = baseCommand
        self.startedKeyword = startedKeyword
        let storedPath = UserDefaults.standard.string(forKey: "\(name)_Path") ?? projectPath
        self.projectPath = storedPath
        self.gitMonitor = GitMonitor(projectPath: storedPath)
        self.nodeVersion = UserDefaults.standard.string(forKey: "\(name)_Node") ?? nodeVersion
        self.javaVersion = UserDefaults.standard.string(forKey: "\(name)_Java") ?? javaVersion
    }

    private func updateStatus(_ newStatus: ProjectStatus) {
        DispatchQueue.main.async { self.status = newStatus }
    }

    func start() {
        guard status == .stopped || status == .error else { return }

        isIntentionallyStopped = false
        updateStatus(.starting)

        process = Process()
        process?.executableURL = URL(fileURLWithPath: "/bin/zsh")

        var prefix = ""
        if let jv = javaVersion {
            prefix += "export JAVA_HOME=$(/usr/libexec/java_home -v \(jv)); "
        }

        // Detect n location (Apple Silicon: /opt/homebrew, Intel: /usr/local)
        let nPath: String
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/n") {
            nPath = "/opt/homebrew/bin/n"
        } else {
            nPath = "/usr/local/bin/n"
        }

        // Properly quote the path to handle spaces (e.g. "Kaizen Freela")
        let quotedPath = "'" + projectPath.replacingOccurrences(of: "'", with: "'\\''" ) + "'"

        let finalCommand: String
        if let nv = nodeVersion {
            // Use `n exec` to isolate the Node version without touching global state
            finalCommand = "\(prefix)cd \(quotedPath) && \(nPath) exec \(nv) \(baseCommand)"
        } else {
            finalCommand = "\(prefix)cd \(quotedPath) && \(baseCommand)"
        }

        // -l (login shell) loads ~/.zprofile so Homebrew PATH is available (mvn, node, etc.)
        process?.arguments = ["-l", "-c", finalCommand]

        let pipe = Pipe()
        process?.standardOutput = pipe
        process?.standardError = pipe

        // Store log next to app support folder so paths with spaces don't cause issues
        let logURL = URL(fileURLWithPath: projectPath).appendingPathComponent("\(name).log")
        // Truncate / create fresh log on each start
        FileManager.default.createFile(atPath: logURL.path, contents: nil, attributes: nil)
        self.logURL = logURL
        DispatchQueue.main.async { self.lastError = "" }

        pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let self = self else { return }
            let data = fileHandle.availableData
            if data.isEmpty { return }

            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }

            if let text = String(data: data, encoding: .utf8) {
                // Keep the last ~800 chars visible for quick error inspection
                DispatchQueue.main.async {
                    self.lastError = String((self.lastError + text).suffix(800))
                    if self.status == .starting {
                        let isReady: Bool
                        if let kw = self.startedKeyword {
                            isReady = text.contains(kw)
                        } else {
                            isReady = true  // any output = running for Node apps
                        }
                        if isReady { self.updateStatus(.running) }
                    }
                }
            }
        }

        process?.terminationHandler = { [weak self] process in
            guard let self = self else { return }
            self.process = nil
            if self.isIntentionallyStopped {
                self.updateStatus(.stopped)
            } else {
                let msg = "Processo encerrado com código \(process.terminationStatus)"
                print("[\(self.name)] \(msg)")
                DispatchQueue.main.async {
                    if self.lastError.isEmpty { self.lastError = msg }
                }
                self.updateStatus(.error)
            }
        }

        do {
            try process?.run()
        } catch {
            let msg = "Falha ao iniciar: \(error.localizedDescription)"
            print("[\(self.name)] \(msg)")
            DispatchQueue.main.async { self.lastError = msg }
            updateStatus(.error)
        }
    }

    func stop() {
        guard status == .starting || status == .running else { return }
        isIntentionallyStopped = true
        if let process = process, process.isRunning { process.terminate() }
        updateStatus(.stopped)
    }

    // MARK: - Log

    private var logURL: URL?

    /// Opens the log file in the default app (Console or TextEdit).
    func openLog() {
        guard let url = logURL else {
            // Build URL from path even if process hasn't started yet
            let fallback = URL(fileURLWithPath: projectPath).appendingPathComponent("\(name).log")
            NSWorkspace.shared.open(fallback)
            return
        }
        NSWorkspace.shared.open(url)
    }
}
