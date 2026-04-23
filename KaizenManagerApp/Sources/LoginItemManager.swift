import Foundation
import ServiceManagement

class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()

    @Published var isEnabled: Bool = false

    private init() {
        self.isEnabled = self.checkStatus()
    }

    private func checkStatus() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    func toggle() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
                DispatchQueue.main.async {
                    self.isEnabled = self.checkStatus()
                }
            } catch {
                print("Failed to toggle login item: \(error)")
            }
        }
    }
}
