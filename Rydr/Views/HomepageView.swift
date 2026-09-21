import SwiftUI
import MapKit
import CoreLocation

struct HomepageView: View {
    @ObservedObject var store = DriveSessionStore.shared
    @State var location = LocationManager()
    @State var position: MapCameraPosition = .automatic
    @State var currentLocation: CLLocationCoordinate2D?

    let goalHours = 50.0

    var body: some View {
        let progress = min(store.totalHours / goalHours, 1)

        ZStack {
            Color.white.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rydr")
                        .font(.custom("Montserrat-ExtraBold", size: 40))
                        .foregroundStyle(.black)

                    Text("View and log driving hours easily!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black.opacity(0.7))
                }

                NavigationLink {
                    DriveSessionView()
                } label: {
                    Text("Start Drive")
                        .font(.custom("Montserrat-ExtraBold", size: 14))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                VStack {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .stroke(Color.black.opacity(0.08), lineWidth: 10)

                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(Color.black, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))

                            Text(String(format: "%.0f%%", progress * 100))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                        .frame(width: 78, height: 78)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Hours logged")
                                .font(.subheadline)
                                .foregroundStyle(.black.opacity(0.7))

                            Text(String(format: "%.f / %.0f", store.totalHours, goalHours))
                                .font(.title2)
                                .foregroundStyle(.black)

                            Text(String(format: "%.f night hours", store.nightHours))
                                .font(.caption)
                                .foregroundStyle(.black.opacity(0.6))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 18)
                }
                .frame(height: 140)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                }

                Map(position: $position) {
                    if let currentLocation {
                        Marker("You", coordinate: currentLocation)
                    }
                }
                .mapStyle(.standard)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    Text("Live location")
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(12)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .onAppear {
            location.onUpdate = { coordinate in
                currentLocation = coordinate

                withAnimation(.easeInOut(duration: 0.5)) {
                    position = .region(
                        MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                        )
                    )
                }
            }

            location.requestLocation()
        }
    }
}

final class LocationManager: NSObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    var onUpdate: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        onUpdate?(coordinate)
    }
}

#Preview {
    MainView()
}
