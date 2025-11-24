import Foundation

class OnboardingManager {
    private static let hasCompletedKey = "HasCompletedOnboarding"

    static func hasCompletedOnboarding() -> Bool {
        return UserDefaults.standard.bool(forKey: hasCompletedKey)
    }

    static func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: hasCompletedKey)
    }
}
