import Foundation
import AppKit

/// Manages the user-selected root folder that contains KS-Service, KS-Mob and KS-Tools.
class ProjectRootManager {
    static let shared = ProjectRootManager()

    private let defaultsKey = "ProjectRootPath"

    var rootPath: String? {
        get { UserDefaults.standard.string(forKey: defaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    func path(for project: String) -> String? {
        guard let root = rootPath else { return nil }
        return (root as NSString).appendingPathComponent(project)
    }

    /// Presents an NSOpenPanel to pick the root folder. Calls completion with true if user confirmed.
    func promptForRootFolder(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "Selecione a pasta raiz dos projetos Kaizen"
            panel.message = "Escolha a pasta que contém KS-Service, KS-Mob e KS-Tools."
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = false
            panel.allowsMultipleSelection = false

            NSApp.activate(ignoringOtherApps: true)

            if panel.runModal() == .OK, let url = panel.url {
                self.rootPath = url.path
                completion(true)
            } else {
                completion(false)
            }
        }
    }
}
