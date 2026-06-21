import Foundation

enum AppEnvironment {
    case debug
    case release

    static var current: AppEnvironment {
        #if DEBUG
        return .debug
        #else
        return .release
        #endif
    }

    /// The plist filename (no extension) that holds credentials for this environment.
    var secretsFileName: String {
        switch self {
        case .debug:   return "Secrets.debug"
        case .release: return "Secrets.release"
        }
    }

    var displayName: String {
        switch self {
        case .debug:   return "Development"
        case .release: return "Production"
        }
    }

    var isDebug: Bool { self == .debug }
}
