import SwiftUI
import MapKit

struct ManualView: View {
    @State var date = Date()
    @State var hours = 0
    @State var minutes = 30
    @State var dayPeriod = DayPeriod.day
    @State var location = LocationManager()
    @State var currentLocation: CLLocationCoordinate2D?
    @State var mapCenter: CLLocationCoordinate2D?
    @State var pin: CLLocationCoordinate2D?
    @State var position: MapCameraPosition = .automatic

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            GeometryReader { proxy in
                let mapHeight = max(150, min(220, proxy.size.height * 0.28))

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add Drive")
                            .font(.custom("Montserrat-ExtraBold", size: 28))
                            .foregroundStyle(.black)

                        Text("Manually log a driving session.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.black.opacity(0.7))
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Session details")
                            .font(.subheadline)
                            .foregroundStyle(.black.opacity(0.7))

                        DatePicker("Date & time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .foregroundStyle(.black)
                            .frame(width: 120, height: 10)
                            .offset(x: 72, y: 5)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Duration")
                                    .font(.caption)
                                    .foregroundStyle(.black.opacity(0.6))
                                    .offset(y: 10)

                                HStack(spacing: 10) {
                                    Picker("Hours", selection: $hours) {
                                        ForEach(0..<10, id: \.self) { number in
                                            Text("\(number)h").tag(number)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 90, height: 50)
                                    .offset(x: -20)

                                    Picker("Minutes", selection: $minutes) {
                                        ForEach([0, 15, 30, 45], id: \.self) { number in
                                            Text("\(number)m").tag(number)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 95, height: 50)
                                    .offset(x: -50)
                                }
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("T.O.D")
                                    .font(.caption)
                                    .foregroundStyle(.black.opacity(0.6))
                                    .offset(x: -50)

                                Picker("Time of Day", selection: $dayPeriod) {
                                    Text("Day").tag(DayPeriod.day)
                                    Text("Night").tag(DayPeriod.night)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 120, height: 10)
                                .offset(x: -50, y: 10)
                            }
                        }
                    }
                    .padding(10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    }
                    .offset(x: -5)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pin a general area")
                            .font(.subheadline)
                            .foregroundStyle(.black)

                        Text("Move the map and set a single pin.")
                            .font(.caption)
                            .foregroundStyle(.black.opacity(0.6))

                        Map(position: $position) {
                            if let currentLocation {
                                Marker("You", coordinate: currentLocation)
                            }

                            if let pin {
                                Marker("Area", coordinate: pin)
                            }
                        }
                        .mapStyle(.standard)
                        .onMapCameraChange { context in
                            mapCenter = context.region.center
                        }
                        .frame(height: mapHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        }
                        .overlay {
                            ZStack {
                                Circle()
                                    .stroke(Color.black.opacity(0.25), lineWidth: 2)
                                    .frame(width: 28, height: 28)

                                Circle()
                                    .fill(.black)
                                    .frame(width: 6, height: 6)
                            }
                        }

                        Button {
                            if let mapCenter {
                                pin = mapCenter
                            }
                        } label: {
                            Text(pin == nil ? "Set Pin Here" : "Update Pin")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        saveDrive()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))

                            Text("Save Drive")
                                .font(.custom("Montserrat-ExtraBold", size: 14))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, -30)
                .padding(.bottom, 6)
            }
        }
        .onAppear {
            location.onUpdate = { coordinate in
                currentLocation = coordinate
                mapCenter = coordinate

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

    func saveDrive() {
        let duration = TimeInterval((hours * 3600) + (minutes * 60))
        let endedAt = date.addingTimeInterval(duration)
        let route = pin.map { [RouteCoordinate($0)] } ?? []

        let session = DriveSession(
            id: UUID(),
            startDate: date,
            endDate: endedAt,
            duration: duration,
            dayPeriod: dayPeriod,
            route: route
        )

        DriveSessionStore.shared.addDrive(session)

        hours = 0
        minutes = 30
        dayPeriod = .day
        pin = nil
    }
}

#Preview {
    MainView()
}
