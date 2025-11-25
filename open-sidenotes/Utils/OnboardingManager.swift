import Foundation

class OnboardingManager {
    private static let hasCompletedKey = "HasCompletedOnboarding"
    private static let hasCreatedWelcomeNoteKey = "HasCreatedWelcomeNote"

    static func hasCompletedOnboarding() -> Bool {
        return UserDefaults.standard.bool(forKey: hasCompletedKey)
    }

    static func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: hasCompletedKey)
    }

    static func hasCreatedWelcomeNote() -> Bool {
        return UserDefaults.standard.bool(forKey: hasCreatedWelcomeNoteKey)
    }

    static func markWelcomeNoteCreated() {
        UserDefaults.standard.set(true, forKey: hasCreatedWelcomeNoteKey)
    }
}
