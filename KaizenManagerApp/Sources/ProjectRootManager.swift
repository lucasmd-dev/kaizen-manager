import Foundation
import AppKit

/// Persists and retrieves the folder path for each individual project.
///
/// Strategy (non-sandboxed app):
///   - On first pick, saves a bookmark (without security scope, since we are not sandboxed)
///     AND the plain path string.
///   - On subsequent launches the plain path is used directly; the bookmark is kept as
///     a resilient fallback that survives renames / moves.
///   - The NSOpenPanel is shown ONLY when no path has been saved yet, or when the user
///     explicitly clicks "Change Folder". It is NEVER shown automatically at every launch.
class ProjectRootManager {
    static let shared = ProjectRootManager()

    // MARK: - Keys

    private func bookmarkKey(for name: String) -> String { "ProjectBookmark_\(name)" }
    private func pathKey(for name: String) -> String     { "ProjectPath_\(name)" }

    // MARK: - Read

    func path(for projectName: String) -> String? {
        // Prefer the stored plain path — fast and always works for non-sandboxed apps
        if let p = UserDefaults.standard.string(forKey: pathKey(for: projectName)), !p.isEmpty {
            return p
        }
        // Fallback: resolve bookmark (handles the case where folder was renamed/moved)
        if let data = UserDefaults.standard.data(forKey: bookmarkKey(for: projectName)) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data,
                                  options: [],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale) {
                let resolved = url.path
                // Re-save the resolved path so future reads are fast
                UserDefaults.standard.set(resolved, forKey: pathKey(for: projectName))
                if stale { saveBookmark(for: url, projectName: projectName) }
                return resolved
            }
        }
        return nil
    }

    // MARK: - Write

    func setPath(_ path: String, for projectName: String) {
        UserDefaults.standard.set(path, forKey: pathKey(for: projectName))
    }

    private func saveBookmark(for url: URL, projectName: String) {
        // Non-sandboxed bookmark — no .withSecurityScope needed
        if let data = try? url.bookmarkData(options: .minimalBookmark,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: bookmarkKey(for: projectName))
        }
    }

    // MARK: - Picker

    /// Opens NSOpenPanel so the user can pick (or re-pick) the folder for a project.
    /// Stores both a plain path string and a bookmark for resilience.
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
                self.saveBookmark(for: url, projectName: projectName)
                completion(url.path)
            } else {
                completion(nil)
            }
        }
    }
}
