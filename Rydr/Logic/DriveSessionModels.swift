import Foundation
import CoreLocation
import Combine

struct DriveSession: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let dayPeriod: DayPeriod
    let route: [RouteCoordinate]
}

enum DayPeriod: String, Codable {
    case day
    case night
}

struct RouteCoordinate: Codable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

final class DriveSessionStore: ObservableObject {
    static let shared = DriveSessionStore()

    @Published var sessions: [DriveSession] = []

    let fileUrl: URL

    private init() {
        let folders = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        fileUrl = (folders.first ?? URL(fileURLWithPath: "/tmp")).appendingPathComponent("drive_sessions.json")
        loadDrives()
    }

    var totalHours: Double {
        sessions.reduce(0) { $0 + $1.duration } / 3600
    }

    var nightHours: Double {
        sessions.filter { $0.dayPeriod == .night }.reduce(0) { $0 + $1.duration } / 3600
    }

    func addDrive(_ session: DriveSession) {
        guard !sessions.contains(where: { $0.id == session.id }) else {
            return
        }

        sessions.insert(session, at: 0)
        saveDrives()
    }

    func deleteDrive(_ session: DriveSession) {
        sessions.removeAll { $0.id == session.id }
        saveDrives()
    }

    func loadDrives() {
        do {
            let data = try Data(contentsOf: fileUrl)
            let savedSessions = try JSONDecoder().decode([DriveSession].self, from: data)
            sessions = savedSessions
        } catch {
            sessions = []
        }
    }

    func saveDrives() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: fileUrl, options: [.atomic])
        } catch {
            print("Drive save error:", error)
        }
    }
}

func getDayPeriod(_ date: Date) -> DayPeriod {
    let hour = Calendar.current.component(.hour, from: date)

    if hour >= 6 && hour < 18 {
        return .day
    }

    return .night
}

func formatDuration(_ duration: TimeInterval) -> String {
    let total = Int(duration)
    let hours = total / 3600
    let minutes = (total % 3600) / 60

    return String(format: "%dh %02dm", hours, minutes)
}

func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short

    return formatter.string(from: date)
}

func formatDateOnly(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none

    return formatter.string(from: date)
}

func formatTimeOnly(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short

    return formatter.string(from: date)
}
