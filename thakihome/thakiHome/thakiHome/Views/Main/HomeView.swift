import SwiftUI
import FirebaseFirestore

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @State private var selectedTab = 0
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isEditing = false
    @Namespace private var animation
    
    @State private var selectedDeviceForDetails: DeviceItem?
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            GeometryReader { geometry in
                let width = geometry.size.width
                
                ZStack(alignment: .bottom) {
                    ZStack(alignment: .leading) {
                        HStack(spacing: 0) {
                            DashboardView(devices: $viewModel.devices, isEditing: $isEditing, viewModel: viewModel, onShowDetails: { dev in selectedDeviceForDetails = dev })
                                .frame(width: width)
                            
                            AllDevicesView(devices: viewModel.devices, viewModel: viewModel, onShowDetails: { dev in selectedDeviceForDetails = dev })
                                .frame(width: width)
                        }
                        .frame(width: width * 2, alignment: .leading)
                        .offset(x: (-CGFloat(currentPage) * width) + dragOffset)
                    }
                    .frame(width: width, alignment: .leading)
                    .clipped()
                    .gesture(
                        DragGesture()
                            .onChanged {
                                if !isEditing { dragOffset = $0.translation.width }
                            }
                            .onEnded { value in
                                guard !isEditing else { return }
                                let threshold = width * 0.2
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if value.translation.width < -threshold && currentPage == 0 { currentPage = 1 }
                                    else if value.translation.width > threshold && currentPage == 1 { currentPage = 0 }
                                    dragOffset = 0
                                }
                            }
                    )

                    VStack {
                        if isEditing {
                            Button(action: { withAnimation { isEditing = false } }) {
                                Text("Done").bold().foregroundColor(.white)
                                    .padding(.vertical, 12).padding(.horizontal, 40)
                                    .background(Color.mainPurple).clipShape(Capsule())
                                    .shadow(radius: 5)
                            }
                        } else {
                            HStack(spacing: 0) {
                                navBtn(t: "Dashboard", i: 0)
                                navBtn(t: "All Devices", i: 1)
                            }
                            .padding(4)
                            .background(.ultraThinMaterial).clipShape(Capsule())
                            .frame(width: 260, height: 50)
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                        }
                    }
                    .padding(.bottom, 25)
                }
                .frame(width: width)
            }
            .background(Color.themeBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            
            .sheet(item: $selectedDeviceForDetails) { device in
                DeviceDetailsView(viewModel: viewModel, initialDevice: device)
            }
            
            Text("Scenes").tabItem { Label("Scenes", systemImage: "bolt.circle.fill") }.tag(1)
            AddDeviceView().tabItem { Label("Add", systemImage: "plus.circle.fill") }.tag(2)
            ProfileView(isLoggedIn: $isLoggedIn).tabItem { Label("Me", systemImage: "person.fill") }.tag(3)
        }
        .accentColor(.mainPurple)
    }
    
    func navBtn(t: String, i: Int) -> some View {
        Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { currentPage = i } }) {
            Text(t).font(.system(size: 14, weight: currentPage == i ? .bold : .medium))
                .foregroundColor(currentPage == i ? .mainPurple : .gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ZStack { if currentPage == i { Capsule().fill(Color.cardBackground).matchedGeometryEffect(id: "tab", in: animation).shadow(radius: 1).padding(2) } })
        }
    }
}
