import Foundation
import Combine

@MainActor
final class SettingsManager: ObservableObject {
    private let defaults: UserDefaults
    @Published var shortcut: Shortcut? {
        didSet { defaults.set(try? JSONEncoder().encode(shortcut), forKey: "shortcut") }
    }
    @Published var executablePath: String {
        didSet { defaults.set(executablePath, forKey: "executablePath") }
    }
    @Published var copyAutomatically: Bool {
        didSet { defaults.set(copyAutomatically, forKey: "copyAutomatically") }
    }
    var hasLaunched: Bool {
        get { defaults.bool(forKey: "hasLaunched") }
        set { defaults.set(newValue, forKey: "hasLaunched") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shortcut = defaults.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
        executablePath = defaults.string(forKey: "executablePath") ?? ""
        copyAutomatically = defaults.object(forKey: "copyAutomatically") as? Bool ?? true
    }
}
