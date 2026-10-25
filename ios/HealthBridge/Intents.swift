import AppIntents

/// "Sync health data" action for the Shortcuts app, so a personal automation
/// (a time of day, or joining the home Wi-Fi) can sync without opening HealthBridge.
struct SyncHealthIntent: AppIntent {
    static var title: LocalizedStringResource = "Sync health data"
    static var description = IntentDescription("Send the days since the last sync to your Mac.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (status, _) = await Sync.shared.run(reason: "shortcut")
        return .result(dialog: "\(status)")
    }
}

struct HealthBridgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SyncHealthIntent(), phrases: ["Sync \(.applicationName)"],
                    shortTitle: "Sync health data", systemImageName: "heart.text.square")
    }
}
