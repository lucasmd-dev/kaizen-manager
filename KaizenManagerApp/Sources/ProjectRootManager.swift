import Foundation
import AppKit

/// Persists and retrieves the folder path for each individual project.
class ProjectRootManager {
    static let shared = ProjectRootManager()

    private func key(for projectName: String) -> String {
        "ProjectPath_\(projectName)"
    }

    func path(for projectName: String) -> String? {
        UserDefaults.standard.string(forKey: key(for: projectName))
    }

    func setPath(_ path: String, for projectName: String) {
        UserDefaults.standard.set(path, forKey: key(for: projectName))
    }

    /// Opens an NSOpenPanel to let the user pick the folder for a specific project.
    func promptForPath(projectName: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "Pasta do \(projectName)"
            panel.message = "Selecione a pasta raiz do projeto \(projectName)."
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = false
            panel.allowsMultipleSelection = false

            NSApp.activate(ignoringOtherApps: true)

            if panel.runModal() == .OK, let url = panel.url {
                self.setPath(url.path, for: projectName)
                completion(url.path)
            } else {
                completion(nil)
            }
        }
    }
}
