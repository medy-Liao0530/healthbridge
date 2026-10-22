import Foundation
import HealthKit
import BackgroundTasks
import CryptoKit

final class Sync {
    static let shared = Sync()
    static let taskID = (Bundle.main.bundleIdentifier ?? "HealthBridge") + ".refresh"
    static var defaultEndpoint: String { Config.endpoint }
    let store = HKHealthStore()
    private(set) var lastSendOK = false

    let sums: [(String, HKQuantityTypeIdentifier, HKUnit)] = [
        ("steps", .stepCount, .count()),
        ("active_kcal", .activeEnergyBurned, .kilocalorie()),
        ("exercise_min", .appleExerciseTime, .minute()),
    ]
    let avgs: [(String, HKQuantityTypeIdentifier)] = [
        ("heart_rate", .heartRate),
        ("resting_hr", .restingHeartRate),
    ]
    var readTypes: Set<HKObjectType> {
        var s: Set<HKObjectType> = [HKObjectType.workoutType()]
        for (_, id, _) in sums { s.insert(HKQuantityType(id)) }
        for (_, id) in avgs { s.insert(HKQuantityType(id)) }
        return s
    }

    func authorize() async -> String {
        guard HKHealthStore.isHealthDataAvailable() else { return L("Health data is not available on this device", "此设备没有健康数据") }
        do { try await store.requestAuthorization(toShare: [], read: readTypes); startObservers(); return L("Authorization requested", "已请求授权") }
        catch { return L("Authorization failed: ", "授权失败：") + error.localizedDescription }
    }

    func startObservers() {
        for t in [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)] as [HKSampleType] {
            let q = HKObserverQuery(sampleType: t, predicate: nil) { _, done, _ in
                Task { await self.run(reason: "observer"); done() }
            }
            store.execute(q)
            store.enableBackgroundDelivery(for: t, frequency: .hourly) { _, _ in }
        }
    }

    static func schedule() {
        let r = BGAppRefreshTaskRequest(identifier: taskID)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        try? BGTaskScheduler.shared.submit(r)
    }

    private func stat(_ id: HKQuantityTypeIdentifier, _ opt: HKStatisticsOptions, _ start: Date, _ end: Date) async -> HKStatistics? {
        await withCheckedContinuation { c in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            store.execute(HKStatisticsQuery(quantityType: HKQuantityType(id), quantitySamplePredicate: pred, options: opt) { _, s, _ in c.resume(returning: s) })
        }
    }

    private func workouts(_ start: Date, _ end: Date) async -> [HKWorkout] {
        await withCheckedContinuation { c in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            store.execute(HKSampleQuery(sampleType: .workoutType(), predicate: pred, limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, s, _ in
                c.resume(returning: (s as? [HKWorkout]) ?? []) })
        }
    }

    func payload(for day: Date) async -> [String: Any] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day), end = cal.date(byAdding: .day, value: 1, to: start)!
        let iso = ISO8601DateFormatter(); iso.timeZone = .current
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        var p: [String: Any] = ["date": df.string(from: start), "generated_at": iso.string(from: Date())]
        for (k, id, unit) in sums {
            if let v = await stat(id, .cumulativeSum, start, end)?.sumQuantity()?.doubleValue(for: unit) { p[k] = (v * 10).rounded() / 10 }
        }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        for (k, id) in avgs {
            if let s = await stat(id, [.discreteAverage, .discreteMax, .discreteMin], start, end) {
                if let v = s.averageQuantity()?.doubleValue(for: bpm) { p[k + "_avg"] = v.rounded() }
                if k == "heart_rate", let v = s.maximumQuantity()?.doubleValue(for: bpm) { p["heart_rate_max"] = v.rounded() }
            }
        }
        var ws: [[String: Any]] = []
        for w in await workouts(start, end) {
            var d: [String: Any] = ["type": w.workoutActivityType.rawValue, "start": iso.string(from: w.startDate),
                                    "end": iso.string(from: w.endDate), "minutes": (w.duration / 6).rounded() / 10]
            if let e = w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity() { d["active_kcal"] = e.doubleValue(for: .kilocalorie()).rounded() }
            if let h = w.statistics(for: HKQuantityType(.heartRate)) {
                if let a = h.averageQuantity() { d["hr_avg"] = a.doubleValue(for: bpm).rounded() }
                if let m = h.maximumQuantity() { d["hr_max"] = m.doubleValue(for: bpm).rounded() }
            }
            if let dist = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity() { d["km"] = (dist.doubleValue(for: .meterUnit(with: .kilo)) * 100).rounded() / 100 }
            ws.append(d)
        }
        p["workouts"] = ws
        return p
    }

    /// Days since the oldest step sample in Health (first day of any recorded data).
    func daysOfHistory() async -> Int {
        let first: Date? = await withCheckedContinuation { c in
            store.execute(HKSampleQuery(sampleType: HKQuantityType(.stepCount), predicate: nil, limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, s, _ in
                c.resume(returning: s?.first?.startDate) })
        }
        guard let first else { return 0 }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: first), to: Date()).day ?? 0
    }

    /// Send history in 30-day chunks, oldest first.
    func backfill(days total: Int, progress: @escaping (String) -> Void) async -> String {
        var offset = total
        while offset >= 0 {
            let chunkEnd = max(offset - 29, 0)
            let r = await runRange(from: offset, to: chunkEnd, reason: "backfill")
            progress(L("Backfilling: \(chunkEnd) days left… ", "补传中：还剩 \(chunkEnd) 天… ") + r)
            if !lastSendOK { return L("Backfill stopped: ", "补传中断：") + r }
            offset = chunkEnd - 1
        }
        return L("Backfill complete (\(total) days)", "历史补传完成（\(total) 天）")
    }

    private func runRange(from back: Int, to end: Int, reason: String) async -> String {
        let now = Date()
        var days: [[String: Any]] = []
        for b in stride(from: back, through: end, by: -1) {
            if let d = Calendar.current.date(byAdding: .day, value: -b, to: now) { days.append(await payload(for: d)) }
        }
        return await send(days: days, reason: reason).0
    }

    @discardableResult
    func run(reason: String, daysBack: Int = 2) async -> (String, String) {
        let now = Date()
        var days: [[String: Any]] = []
        for back in stride(from: daysBack, through: 0, by: -1) {
            if let d = Calendar.current.date(byAdding: .day, value: -back, to: now) { days.append(await payload(for: d)) }
        }
        return await send(days: days, reason: reason)
    }

    func send(days: [[String: Any]], reason: String) async -> (String, String) {
        lastSendOK = false
        let now = Date()
        let body: [String: Any] = ["source": "HealthBridge", "reason": reason, "sent_at": Int(now.timeIntervalSince1970), "days": days]
        guard let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .prettyPrinted]) else { return (L("Encoding failed", "编码失败"), "") }
        let text = String(data: data, encoding: .utf8) ?? ""
        let saved = UserDefaults.standard.string(forKey: "endpoint")?.trimmingCharacters(in: .whitespaces) ?? ""
        guard let url = URL(string: saved.isEmpty ? Sync.defaultEndpoint : saved), url.host != nil else { return (L("Invalid receiver address", "接收地址无效"), text) }
        let secret = Config.secret
        let key = SymmetricKey(data: SHA256.hash(data: Data(secret.utf8)))
        guard let sealed = try? AES.GCM.seal(data, using: key).combined else { return (L("Encryption failed", "加密失败"), text) }
        var urls = [url]
        if let ip = Config.fallbackHost, let fb = URL(string: "http://\(ip):\(Config.port)/health"), fb != url { urls.append(fb) }
        var lastError = ""
        for u in urls {
            var req = URLRequest(url: u); req.httpMethod = "POST"; req.httpBody = sealed
            req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type"); req.timeoutInterval = 10
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200 { lastSendOK = true; return (L("Sent ", "已发送 ") + "\(Date().formatted(date: .omitted, time: .shortened)) (\(u.host ?? ""))", text) }
                return (L("Mac answered ", "Mac 返回 ") + "\(code) (\(u.host ?? ""))", text)  // got an answer: never retry elsewhere
            } catch { lastError = L("Send failed ", "发送失败 ") + "(\(u.host ?? "")): \(error.localizedDescription)" }
        }
        return (lastError, text)
    }
}

/// Pick English or Chinese by the phone's preferred language.
func L(_ en: String, _ zh: String) -> String {
    (Locale.preferredLanguages.first ?? "").hasPrefix("zh") ? zh : en
}
