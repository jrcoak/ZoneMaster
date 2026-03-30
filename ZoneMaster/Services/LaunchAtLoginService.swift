import ServiceManagement

/// Manages launch-at-login registration using SMAppService (macOS 13+).
final class LaunchAtLoginService {

    /// Register or unregister the app as a login item
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("ZoneMaster: Failed to \(enabled ? "register" : "unregister") login item: \(error)")
        }
    }

    /// Check current registration status
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
