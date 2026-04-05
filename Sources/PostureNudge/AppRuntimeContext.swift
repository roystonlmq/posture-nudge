import Foundation

enum AppRuntimeContext {
    static var isRunningAsAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame
    }
}
