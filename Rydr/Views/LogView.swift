import SwiftUI
import MapKit

struct LogView: View {
    @ObservedObject var store = DriveSessionStore.shared

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Text("Drive Log")
                        .font(.custom("Montserrat-ExtraBold", size: 28))
                        .foregroundStyle(.black)

                    if store.sessions.isEmpty {
                        Text("No drives saved yet!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.black.opacity(0.7))
                            .offset(y: -20)
                    } else {
                        ForEach(store.sessions) { session in
                            let route = session.route.map { $0.coordinate }

                            NavigationLink {
                                DriveLogDetailView(session: session, store: store)
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    Map(position: .constant(.region(getRegion(route)))) {
                                        if route.count > 1 {
                                            MapPolyline(coordinates: route)
                                                .stroke(.black, lineWidth: 3)
                                        }

                                        if let first = route.first {
                                            Marker("Start", coordinate: first)
                                        }
                                    }
                                    .mapStyle(.standard)
                                    .frame(height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(formatDate(session.startDate))
                                            .font(.subheadline)
                                            .foregroundStyle(.black)

                                        Text("Duration: \(formatDuration(session.duration))")
                                            .font(.caption)
                                            .foregroundStyle(.black.opacity(0.7))

                                        Text("Time of Day: \(session.dayPeriod.rawValue.capitalized)")
                                            .font(.caption)
                                            .foregroundStyle(.black.opacity(0.7))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(14)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

struct DriveLogDetailView: View {
    @Environment(\.dismiss) var dismiss

    let session: DriveSession
    let store: DriveSessionStore

    var body: some View {
        let route = session.route.map { $0.coordinate }

        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Drive Details")
                        .font(.custom("Montserrat-ExtraBold", size: 28))
                        .foregroundStyle(.black)

                    Map(position: .constant(.region(getRegion(route)))) {
                        if route.count > 1 {
                            MapPolyline(coordinates: route)
                                .stroke(.black, lineWidth: 4)
                        }

                        if let first = route.first {
                            Marker("Start", coordinate: first)
                        }

                        if let last = route.last {
                            Marker("End", coordinate: last)
                        }
                    }
                    .mapStyle(.standard)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start")
                                    .font(.subheadline)
                                    .foregroundStyle(.black.opacity(0.7))

                                Text(formatDateOnly(session.startDate))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.black)

                                Text(formatTimeOnly(session.startDate))
                                    .font(.caption)
                                    .foregroundStyle(.black.opacity(0.6))
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("End")
                                    .font(.subheadline)
                                    .foregroundStyle(.black.opacity(0.7))

                                Text(formatDateOnly(session.endDate))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.black)

                                Text(formatTimeOnly(session.endDate))
                                    .font(.caption)
                                    .foregroundStyle(.black.opacity(0.6))
                            }
                        }

                        Divider()
                            .overlay(Color.black.opacity(0.08))

                        HStack(alignment: .firstTextBaseline) {
                            Text("Duration")
                                .font(.subheadline)
                                .foregroundStyle(.black.opacity(0.7))

                            Spacer()

                            Text(formatDuration(session.duration))
                                .font(.subheadline)
                                .foregroundStyle(.black)
                        }

                        HStack(alignment: .firstTextBaseline) {
                            Text("Time of Day")
                                .font(.subheadline)
                                .foregroundStyle(.black.opacity(0.7))

                            Spacer()

                            Text(session.dayPeriod.rawValue.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    }

                    Button {
                        store.deleteDrive(session)
                        dismiss()
                    } label: {
                        Text("Remove Session")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

func getRegion(_ route: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
    if route.isEmpty {
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }

    var minLat = route[0].latitude
    var maxLat = route[0].latitude
    var minLon = route[0].longitude
    var maxLon = route[0].longitude

    for coordinate in route {
        minLat = min(minLat, coordinate.latitude)
        maxLat = max(maxLat, coordinate.latitude)
        minLon = min(minLon, coordinate.longitude)
        maxLon = max(maxLon, coordinate.longitude)
    }

    let center = CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
    )

    let span = MKCoordinateSpan(
        latitudeDelta: max(maxLat - minLat, 0.01) * 1.6,
        longitudeDelta: max(maxLon - minLon, 0.01) * 1.6
    )

    return MKCoordinateRegion(center: center, span: span)
}

#Preview {
    MainView()
}
