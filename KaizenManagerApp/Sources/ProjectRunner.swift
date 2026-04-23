import Foundation
import Combine

enum ProjectStatus {
    case stopped
    case starting
    case running
    case error
}

class ProjectRunner: ObservableObject {
    let name: String
    let projectPath: String
    let baseCommand: String

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

    init(name: String, projectPath: String, baseCommand: String, nodeVersion: String? = nil, javaVersion: String? = nil) {
        self.name = name
        self.projectPath = projectPath
        self.baseCommand = baseCommand
        self.gitMonitor = GitMonitor(projectPath: projectPath)
        self.nodeVersion = UserDefaults.standard.string(forKey: "\(name)_Node") ?? nodeVersion
        self.javaVersion = UserDefaults.standard.string(forKey: "\(name)_Java") ?? javaVersion
    }

    private func updateStatus(_ newStatus: ProjectStatus) {
        DispatchQueue.main.async {
            self.status = newStatus
        }
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

        var finalCommand: String
        if let nv = nodeVersion {
            // Use `n exec` to isolate the Node version without touching global state
            finalCommand = "\(prefix)cd \(projectPath) && /opt/homebrew/bin/n exec \(nv) \(baseCommand)"
        } else {
            finalCommand = "\(prefix)cd \(projectPath) && source ~/.zshrc 2>/dev/null; \(baseCommand)"
        }

        process?.arguments = ["-c", finalCommand]

        let pipe = Pipe()
        process?.standardOutput = pipe
        process?.standardError = pipe

        let logURL = URL(fileURLWithPath: projectPath).appendingPathComponent("\(name).log")
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil, attributes: nil)
        }

        pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let self = self else { return }
            let data = fileHandle.availableData
            if data.isEmpty { return }

            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }

            if String(data: data, encoding: .utf8) != nil {
                if self.status == .starting {
                    self.updateStatus(.running)
                }
            }
        }

        process?.terminationHandler = { [weak self] process in
            guard let self = self else { return }
            self.process = nil

            if self.isIntentionallyStopped {
                self.updateStatus(.stopped)
            } else {
                self.updateStatus(.error)
                print("[\(self.name)] Exited with status \(process.terminationStatus)")
            }
        }

        do {
            try process?.run()
        } catch {
            print("[\(self.name)] Failed to start: \(error)")
            updateStatus(.error)
        }
    }

    func stop() {
        guard status == .starting || status == .running else { return }

        isIntentionallyStopped = true

        if let process = process, process.isRunning {
            process.terminate()
        }

        updateStatus(.stopped)
    }
}
