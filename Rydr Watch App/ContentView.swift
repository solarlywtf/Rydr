import SwiftUI
import WatchKit
import CoreLocation

struct ContentView: View {
    @AppStorage("watchActiveDriveStart") private var activeDriveStart: Double = 0
    @AppStorage("watchLastDriveStart") private var lastDriveStart: Double = 0
    @AppStorage("watchLastDriveEnd") private var lastDriveEnd: Double = 0
    @AppStorage("watchLastDriveDuration") private var lastDriveDuration: Double = 0
    @AppStorage("watchActiveDriveRoute") private var activeDriveRouteData: Data = Data()

    @State private var location = WatchDriveLocationManager()
    @State private var route: [WatchRouteCoordinate] = []

    private var isDriveActive: Bool {
        activeDriveStart > 0
    }

    private var activeStartDate: Date {
        Date(timeIntervalSince1970: activeDriveStart)
    }

    private var lastDrive: WatchDriveSummary? {
        guard lastDriveStart > 0, lastDriveEnd > 0, lastDriveDuration > 0 else {
            return nil
        }

        return WatchDriveSummary(
            startDate: Date(timeIntervalSince1970: lastDriveStart),
            endDate: Date(timeIntervalSince1970: lastDriveEnd),
            duration: lastDriveDuration
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    if isDriveActive {
                        ActiveDriveCard(
                            startDate: activeStartDate,
                            routePointCount: route.count,
                            stopAction: stopDrive
                        )
                    } else {
                        StartDriveCard(startAction: startDrive)
                    }

                    if let lastDrive {
                        LastDriveCard(summary: lastDrive)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 10)
            }
            .navigationTitle("Rydr")
        }
        .tint(.white)
        .onAppear {
            restoreActiveRoute()
            location.onUpdate = addRoutePoint

            if isDriveActive {
                location.startTracking()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(isDriveActive ? "Drive running" : "Ready to drive")
                .font(.headline)

            Text(isDriveActive ? "Started at \(activeStartDate.formatted(date: .omitted, time: .shortened))" : "Track your next session from your wrist.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startDrive() {
        activeDriveStart = Date().timeIntervalSince1970
        route = []
        saveActiveRoute()
        location.startTracking()
        WatchHaptics.play(.start)
    }

    private func stopDrive() {
        let endDate = Date()
        let startDate = activeStartDate
        let duration = max(0, endDate.timeIntervalSince(startDate))
        let driveID = UUID()
        let completedRoute = route

        lastDriveStart = startDate.timeIntervalSince1970
        lastDriveEnd = endDate.timeIntervalSince1970
        lastDriveDuration = duration
        activeDriveStart = 0
        activeDriveRouteData = Data()
        route = []
        location.stopTracking()

        WatchDriveSyncManager.shared.sendCompletedDrive(
            id: driveID,
            startDate: startDate,
            endDate: endDate,
            duration: duration,
            route: completedRoute
        )
        WatchHaptics.play(.success)
    }

    private func restoreActiveRoute() {
        guard !activeDriveRouteData.isEmpty else {
            route = []
            return
        }

        route = (try? JSONDecoder().decode([WatchRouteCoordinate].self, from: activeDriveRouteData)) ?? []
    }

    private func saveActiveRoute() {
        activeDriveRouteData = (try? JSONEncoder().encode(route)) ?? Data()
    }

    private func addRoutePoint(_ coordinate: CLLocationCoordinate2D) {
        let newPoint = WatchRouteCoordinate(coordinate)

        if let lastPoint = route.last {
            let oldLocation = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
            let newLocation = CLLocation(latitude: newPoint.latitude, longitude: newPoint.longitude)

            if newLocation.distance(from: oldLocation) < 8 {
                return
            }
        }

        route.append(newPoint)
        saveActiveRoute()
    }
}

private enum WatchHaptics {
    static func play(_ type: WKHapticType) {
        guard !ProcessInfo.processInfo.isRunningForPreviews else {
            return
        }

        WKInterfaceDevice.current().play(type)
    }
}

private struct StartDriveCard: View {
    let startAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusBadge(title: "Stopped", systemImage: "pause.circle.fill")

            Text("Start Drive")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.black)

            Button(action: startAction) {
                Label("Start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint("Starts a new drive timer")
        }
        .cardStyle()
    }
}

private struct ActiveDriveCard: View {
    let startDate: Date
    let routePointCount: Int
    let stopAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusBadge(title: "Recording", systemImage: "record.circle.fill")

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(Self.durationText(context.date.timeIntervalSince(startDate)))
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Elapsed time")
                    .accessibilityValue(Self.accessibilityDurationText(context.date.timeIntervalSince(startDate)))
            }

            MetricRow(title: "Route Points", value: "\(routePointCount)")

            Button(role: .destructive, action: stopAction) {
                Label("Stop", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.red)
            .accessibilityHint("Stops and saves this drive")
        }
        .cardStyle()
    }

    private static func durationText(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func accessibilityDurationText(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours) hours, \(minutes) minutes, \(seconds) seconds"
        }

        return "\(minutes) minutes, \(seconds) seconds"
    }
}

private struct LastDriveCard: View {
    let summary: WatchDriveSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Drive")
                .font(.subheadline.weight(.semibold))

            MetricRow(title: "Duration", value: summary.durationText)
            MetricRow(title: "Ended", value: summary.endDate.formatted(date: .omitted, time: .shortened))
            MetricRow(title: "Period", value: summary.dayPeriod)
        }
        .cardStyle()
    }
}

private struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }
}

private struct StatusBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.secondary)
    }
}

private struct WatchDriveSummary {
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval

    var durationText: String {
        let totalSeconds = max(0, Int(duration))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(max(1, minutes))m"
    }

    var dayPeriod: String {
        let hour = Calendar.current.component(.hour, from: startDate)
        return hour >= 6 && hour < 18 ? "Day" : "Night"
    }
}

struct WatchRouteCoordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var userInfoValue: [String: Double] {
        [
            "latitude": latitude,
            "longitude": longitude
        ]
    }
}

final class WatchDriveLocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onUpdate: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
    }

    func startTracking() {
        guard !ProcessInfo.processInfo.isRunningForPreviews else {
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            return
        }

        onUpdate?(coordinate)
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension ProcessInfo {
    var isRunningForPreviews: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

#Preview {
    ContentView()
}
