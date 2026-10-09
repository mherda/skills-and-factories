import Foundation

/// Launch arguments the factory uses to take screenshots of any screen
/// (see CLAUDE.md, Screens). Debug builds only: release builds ignore them.
///
///     xcrun simctl launch <udid> <bundle id> -factoryScreen settings -factoryNoPrompts
enum FactoryLaunch {
    #if DEBUG
    /// The screen named by `-factoryScreen <name>`, or nil. Launch arguments
    /// of the form `-key value` land in UserDefaults' argument domain.
    static var screen: String? { UserDefaults.standard.string(forKey: "factoryScreen") }

    /// `-factoryNoPrompts`: skip permission requests (location, notifications,
    /// Health, ...) so system alerts don't cover screenshots. Every place that
    /// asks for a permission must check this first.
    static var noPrompts: Bool { ProcessInfo.processInfo.arguments.contains("-factoryNoPrompts") }
    #else
    static let screen: String? = nil
    static let noPrompts = false
    #endif
}
