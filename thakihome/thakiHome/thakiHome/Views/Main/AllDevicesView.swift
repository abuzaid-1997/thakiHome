import SwiftUI

struct AllDevicesView: View {
    let devices: [DeviceItem]
    var viewModel: HomeViewModel
    var onShowDetails: (DeviceItem) -> Void
    
    @State private var hapticTimer: Timer?
    @State private var hapticIntensity: CGFloat = 0.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("All Devices").font(.largeTitle).bold().foregroundColor(.mainPurple).padding(.horizontal)
                
                if devices.isEmpty {
                    Text("No devices found").padding().foregroundColor(.gray)
                } else {
                    let rooms = Array(Set(devices.map { $0.safeRoom })).sorted()
                    ForEach(rooms, id: \.self) { room in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(room.uppercased()).font(.caption).bold().foregroundColor(.gray).padding(.horizontal)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 15)]) {
                                ForEach(devices.filter { $0.safeRoom == room }) { d in
                                    SmallContent(d: d)
                                        .frame(height: 100)
                                        .background(Color.cardBackground)
                                        .cornerRadius(18)
                                        .shadow(color: Color.black.opacity(0.1), radius: 3, y: 2)
                                        .onTapGesture {
                                            viewModel.toggleStatus(d)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }
                                        .onLongPressGesture(minimumDuration: 0.6) {
                                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                                            generator.impactOccurred(intensity: 1.0)
                                            onShowDetails(d)
                                        }
                                }
                            }.padding(.horizontal)
                        }
                    }
                }
            }.padding(.top, 60).padding(.bottom, 120)
        }
    }
}
