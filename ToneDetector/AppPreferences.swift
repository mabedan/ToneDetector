import Foundation
import SwiftUI

struct AppPreferences {
    static let agreeablePromptKey = "agreeablePrompt"

    static let agreeablePromptDidChangeNotification = Notification.Name("agreeablePromptDidChange")

    static let defaultAgreeablePrompt: String = "Is the following text agreeable in tone? Consider politeness, empathy, non-aggressiveness and non-confrontational tone. Consider the context of a work environment, bringing up potential issues is ok, but the tone should not be dismissive or confrontational, but rather constructive and respectful."

    static func getAgreeablePrompt() -> String {
        if let stored = UserDefaults.standard.string(forKey: agreeablePromptKey), !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stored
        }
        return defaultAgreeablePrompt
    }

    static func setAgreeablePrompt(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: agreeablePromptKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: agreeablePromptKey)
        }
        NotificationCenter.default.post(name: agreeablePromptDidChangeNotification, object: nil)
    }

    static func resetAgreeablePrompt() {
        UserDefaults.standard.removeObject(forKey: agreeablePromptKey)
        NotificationCenter.default.post(name: agreeablePromptDidChangeNotification, object: nil)
    }

    static var agreeablePrompt: String {
        get { getAgreeablePrompt() }
        set { setAgreeablePrompt(newValue) }
    }
}
