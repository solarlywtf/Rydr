import Foundation
import WatchConnectivity

final class WatchDriveSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchDriveSyncManager()

    private let pendingDrivesKey = "pendingWatchDriveTransfers"
    private var pendingDrives: [[String: Any]] = []

    private override init() {
        super.init()
        pendingDrives = Self.loadPendingDrives(forKey: pendingDrivesKey)
    }

    func start() {
        guard WCSession.isSupported() else {
            return
        }

        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendCompletedDrive(
        id: UUID,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        route: [WatchRouteCoordinate]
    ) {
        let payload: [String: Any] = [
            "type": "completedDrive",
            "id": id.uuidString,
            "startDate": startDate.timeIntervalSince1970,
            "endDate": endDate.timeIntervalSince1970,
            "duration": duration,
            "dayPeriod": Self.dayPeriod(for: startDate),
            "route": route.map(\.userInfoValue)
        ]

        pendingDrives.append(payload)
        savePendingDrives()
        flushPendingDrives()
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else {
            return
        }

        flushPendingDrives()
    }

    private func flushPendingDrives() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else {
            return
        }

        let drivesToSend = pendingDrives
        pendingDrives.removeAll()
        savePendingDrives()

        for drive in drivesToSend {
            WCSession.default.transferUserInfo(drive)
        }
    }

    private func savePendingDrives() {
        let propertyListDrives = pendingDrives.map { NSDictionary(dictionary: $0) }
        UserDefaults.standard.set(propertyListDrives, forKey: pendingDrivesKey)
    }

    private static func loadPendingDrives(forKey key: String) -> [[String: Any]] {
        guard let storedDrives = UserDefaults.standard.array(forKey: key) as? [[String: Any]] else {
            return []
        }

        return storedDrives
    }

    private static func dayPeriod(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 6 && hour < 18 ? "day" : "night"
    }
}
