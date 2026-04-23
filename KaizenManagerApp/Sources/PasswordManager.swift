import Foundation
import Security

class PasswordManager: ObservableObject {
    static let shared = PasswordManager()

    @Published var hasPassword: Bool = false
    @Published var showPasswordPrompt: Bool = false

    private var _password: String?

    func setPassword(_ pass: String) {
        _password = pass
        hasPassword = true
        showPasswordPrompt = false
    }

    func getPassword() -> String? {
        return _password
    }

    // Shows the sudo password prompt; caller must retry the action after the user submits.
    func requestPasswordIfNeeded(completion: @escaping (Bool) -> Void) {
        if hasPassword {
            completion(true)
        } else {
            DispatchQueue.main.async {
                self.showPasswordPrompt = true
                completion(false)
            }
        }
    }
}
