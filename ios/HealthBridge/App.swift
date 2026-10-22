import SwiftUI
import HealthKit
import BackgroundTasks

@main
struct HealthBridgeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { WindowGroup { ContentView() } }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Sync.taskID, using: nil) { task in
            Sync.schedule()
            Task { await Sync.shared.run(reason: "bgtask"); task.setTaskCompleted(success: true) }
        }
        Sync.shared.startObservers()
        Sync.schedule()
        return true
    }
}

struct ContentView: View {
    @AppStorage("endpoint") var endpoint = Sync.defaultEndpoint
    @State private var status = L("Not synced yet", "未同步")
    @State private var summary = ""
    var body: some View {
        NavigationStack {
            Form {
                Section(L("Receiver (your Mac; data is encrypted first)", "接收地址（你的 Mac，数据先加密再发）")) {
                    TextField("http://…", text: $endpoint).keyboardType(.URL).autocorrectionDisabled().textInputAutocapitalization(.never) }
                Section {
                    Button(L("Allow Health access", "授权健康数据")) { Task { status = await Sync.shared.authorize() } }
                    Button(L("Sync now", "立即同步")) { Task { let r = await Sync.shared.run(reason: "manual"); status = r.0; summary = r.1 } }
                    Button(L("Backfill all history", "补传全部历史")) { Task {
                        let n = await Sync.shared.daysOfHistory()
                        status = L("\(n) days, backfilling…", "共 \(n) 天，补传中…")
                        status = await Sync.shared.backfill(days: n) { p in Task { @MainActor in status = p } }
                    } }
                }
                Section(L("Status", "状态")) { Text(status); if !summary.isEmpty { Text(summary).font(.footnote.monospaced()) } }
            }.navigationTitle("HealthBridge")
        }
    }
}
