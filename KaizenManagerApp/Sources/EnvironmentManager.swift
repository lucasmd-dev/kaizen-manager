import Foundation
import Combine

class EnvironmentManager: ObservableObject {
    @Published var globalJavaVersion: String {
        didSet {
            UserDefaults.standard.set(globalJavaVersion, forKey: "Global_Java")
            applyJavaVersion()
        }
    }

    @Published var globalNodeVersion: String {
        didSet {
            UserDefaults.standard.set(globalNodeVersion, forKey: "Global_Node")
            applyNodeVersion()
        }
    }

    @Published var installedNodeVersions: [String] = []
    @Published var installedJavaVersions: [String] = []

    init() {
        self.globalJavaVersion = UserDefaults.standard.string(forKey: "Global_Java") ?? "17"
        self.globalNodeVersion = UserDefaults.standard.string(forKey: "Global_Node") ?? "20"
        loadInstalledVersions()
    }

    private func loadInstalledVersions() {
        DispatchQueue.global(qos: .userInitiated).async {
            let nodes = self.detectInstalledNodeVersions()
            let javas = self.detectInstalledJavaVersions()
            DispatchQueue.main.async {
                self.installedNodeVersions = nodes
                self.installedJavaVersions = javas
                if !nodes.isEmpty && !nodes.contains(self.globalNodeVersion) {
                    self.globalNodeVersion = nodes.last ?? self.globalNodeVersion
                }
                if !javas.isEmpty && !javas.contains(self.globalJavaVersion) {
                    self.globalJavaVersion = javas.first ?? self.globalJavaVersion
                }
            }
        }
    }

    private func detectInstalledNodeVersions() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/n")
        process.arguments = ["ls"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output
            .components(separatedBy: .newlines)
            .filter { $0.hasPrefix("node/") }
            .compactMap { line -> String? in
                let version = line.replacingOccurrences(of: "node/", with: "")
                return version.isEmpty ? nil : version
            }
    }

    private func detectInstalledJavaVersions() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")
        process.arguments = ["-V"]
        let pipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = pipe  // java_home -V outputs to stderr
        try? process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output
            .components(separatedBy: .newlines)
            .filter { $0.contains("(arm64)") || $0.contains("(x86_64)") }
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard let versionStr = trimmed.components(separatedBy: " ").first else { return nil }
                return versionStr.components(separatedBy: ".").first
            }
            .removingDuplicates()
    }

    private func applyJavaVersion() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")
        process.arguments = ["-v", globalJavaVersion]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
            let zshrcURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc")
            var content = (try? String(contentsOf: zshrcURL, encoding: .utf8)) ?? ""
            let exportLine = "export JAVA_HOME=\(path)"
            if let regex = try? NSRegularExpression(pattern: "^export JAVA_HOME=.*$", options: .anchorsMatchLines) {
                let range = NSRange(content.startIndex..<content.endIndex, in: content)
                if regex.firstMatch(in: content, options: [], range: range) != nil {
                    content = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: exportLine)
                } else {
                    content += "\n\(exportLine)\n"
                }
            } else {
                content += "\n\(exportLine)\n"
            }
            try? content.write(to: zshrcURL, atomically: true, encoding: .utf8)
        }
    }

    private func applyNodeVersion() {
        PasswordManager.shared.requestPasswordIfNeeded { [weak self] hasPass in
            guard let self = self, hasPass, let pass = PasswordManager.shared.getPassword() else { return }
            let version = self.globalNodeVersion
            DispatchQueue.global(qos: .background).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                let command = "echo '\(pass)' | sudo -S /opt/homebrew/bin/n \(version) && node --version"
                process.arguments = ["-c", command]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                try? process.run()
                process.waitUntilExit()
            }
        }
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
