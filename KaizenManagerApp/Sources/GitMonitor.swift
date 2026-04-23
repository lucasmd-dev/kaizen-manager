import Foundation
import Combine

class GitMonitor: ObservableObject {
    @Published var currentBranch: String = "..."
    @Published var availableBranches: [String] = []

    private let projectPath: String
    private var timer: Timer?

    init(projectPath: String) {
        self.projectPath = projectPath
        fetchBranchSync()
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
    }

    private func fetchBranchSync() {
        let output = runGit(args: ["rev-parse", "--abbrev-ref", "HEAD"])
        if !output.isEmpty { self.currentBranch = output }
    }

    private func startMonitoring() {
        fetchData()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchData()
        }
    }

    private func fetchData() {
        DispatchQueue.global(qos: .background).async {
            self.fetchBranch()
            self.fetchAvailableBranches()
        }
    }

    private func fetchBranch() {
        let output = runGit(args: ["rev-parse", "--abbrev-ref", "HEAD"])
        if !output.isEmpty {
            DispatchQueue.main.async {
                if self.currentBranch != output { self.currentBranch = output }
            }
        }
    }

    private func fetchAvailableBranches() {
        let output = runGit(args: ["branch", "--format=%(refname:short)"])
        if !output.isEmpty {
            let branches = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            DispatchQueue.main.async {
                if self.availableBranches != branches { self.availableBranches = branches }
            }
        }
    }

    func checkout(branch: String) {
        if branch == currentBranch { return }
        DispatchQueue.global(qos: .background).async {
            _ = self.runGit(args: ["checkout", branch])
            self.fetchData()
        }
    }

    func fetchRemote(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .background).async {
            _ = self.runGit(args: ["fetch", "--prune"])
            self.fetchData()
            DispatchQueue.main.async { completion() }
        }
    }

    private func runGit(args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
}
