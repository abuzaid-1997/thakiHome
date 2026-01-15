import SwiftUI

struct DashboardView: View {
    @Binding var devices: [DeviceItem]
    @Binding var isEditing: Bool
    var viewModel: HomeViewModel
    var onShowDetails: (DeviceItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("My Home").font(.largeTitle).bold().foregroundColor(.mainPurple).padding(.horizontal)
                
                let dashboardDevices = devices.filter { $0.safeShowOnDashboard }
                
                if dashboardDevices.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "square.grid.2x2").font(.largeTitle).foregroundColor(.gray)
                        Text("No dashboard items").foregroundColor(.gray)
                        if !devices.isEmpty {
                            Text("Go to 'All Devices' to add items").font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                    }.frame(height: 300).frame(maxWidth: .infinity)
                } else {
                    AdvancedLayoutEngine(
                        devices: $devices,
                        viewModel: viewModel,
                        isEditing: isEditing,
                        onShowDetails: onShowDetails,
                        onResize: { d in withAnimation(.spring()) { viewModel.resizeDevice(d) } },
                        onDelete: { d in withAnimation { viewModel.removeFromDashboard(d) }},
                        onStart: { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(); withAnimation { isEditing = true } },
                        onToggle: { d in viewModel.toggleStatus(d) }
                    )
                }
            }
            .padding(.top, 60).padding(.bottom, 120)
        }
    }
}
