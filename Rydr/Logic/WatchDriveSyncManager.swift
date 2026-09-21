import Foundation
import WatchConnectivity
import CoreLocation

final class WatchDriveSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchDriveSyncManager()

    private override init() {
        super.init()
    }

    func start() {
        guard WCSession.isSupported() else {
            return
        }

        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let drive = WatchDrivePayload(userInfo: userInfo) else {
            return
        }

        DispatchQueue.main.async {
            DriveSessionStore.shared.addDrive(drive.session)
        }
    }
}

private struct WatchDrivePayload {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let dayPeriod: DayPeriod
    let route: [RouteCoordinate]

    init?(userInfo: [String: Any]) {
        guard
            userInfo["type"] as? String == "completedDrive",
            let idString = userInfo["id"] as? String,
            let id = UUID(uuidString: idString),
            let startTime = userInfo["startDate"] as? TimeInterval,
            let endTime = userInfo["endDate"] as? TimeInterval,
            let duration = userInfo["duration"] as? TimeInterval,
            let dayPeriodValue = userInfo["dayPeriod"] as? String,
            let dayPeriod = DayPeriod(rawValue: dayPeriodValue)
        else {
            return nil
        }

        self.id = id
        startDate = Date(timeIntervalSince1970: startTime)
        endDate = Date(timeIntervalSince1970: endTime)
        self.duration = duration
        self.dayPeriod = dayPeriod
        route = Self.decodeRoute(from: userInfo["route"])
    }

    var session: DriveSession {
        DriveSession(
            id: id,
            startDate: startDate,
            endDate: endDate,
            duration: duration,
            dayPeriod: dayPeriod,
            route: route
        )
    }

    private static func decodeRoute(from value: Any?) -> [RouteCoordinate] {
        guard let routeValues = value as? [[String: Double]] else {
            return []
        }

        return routeValues.compactMap { value in
            guard let latitude = value["latitude"], let longitude = value["longitude"] else {
                return nil
            }

            return RouteCoordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
    }
}
