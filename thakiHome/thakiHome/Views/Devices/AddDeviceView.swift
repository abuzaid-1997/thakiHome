import SwiftUI

struct AddDeviceView: View {
    @StateObject private var bleManager = BluetoothManager()
    @State private var showSetupWizard = false
    @State private var selectedDevice: ManualDeviceItem?
    @State private var scanTimedOut = false
    
    // للتحكم بالأنيميشن
    @Namespace private var animationSpace
    @State private var showShockwave = false
    
    // متغيرات الحركة الفيزيائية
    @State private var currentOffset: CGFloat = 0
    @State private var lastOffset: CGFloat = 0
    @State private var isOffsetInitialized = false
    
    let manualDevices: [ManualDeviceItem] = [
        ManualDeviceItem(name: "Water Tank Monitor", icon: "drop.fill", color: .cyan, type: .waterSensor),
        ManualDeviceItem(name: "Air Purifier", icon: "wind", color: .mint, type: .airPurifier),
        ManualDeviceItem(name: "Dehumidifier", icon: "humidity.fill", color: .indigo, type: .dehumidifier),
        ManualDeviceItem(name: "Gas Cylinder", icon: "flame.fill", color: .orange, type: .gasSensor),
        ManualDeviceItem(name: "Smart Switch", icon: "switch.2", color: .mainPurple, type: .smartSwitch),
        ManualDeviceItem(name: "Smart Curtain", icon: "curtains.closed", color: .pink, type: .curtain),
        ManualDeviceItem(name: "Door Lock", icon: "lock.shield.fill", color: .gray, type: .lock),
        ManualDeviceItem(name: "Irrigation System", icon: "leaf.fill", color: .green, type: .irrigation)
    ]

    let columns = [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    
                    // الخلفية العامة
                    LinearGradient(
                        colors: [Color.mainPurple.opacity(0.12), Color.themeBackground],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .ignoresSafeArea()
                    
                    // MARK: - 1. Radar Layer
                    VStack {
                        Spacer().frame(height: 50)
                        radarContent
                        Spacer()
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(calculateOpacity(totalHeight: geometry.size.height))
                    // نسمح باللمس فقط في المنطقة المكشوفة من الرادار
                    .allowsHitTesting(currentOffset > geometry.size.height * 0.2)
                    
                    // MARK: - 2. Manual List Layer (The Sheet)
                    let cardHeight = geometry.size.height * 0.92
                    let collapsedPos = cardHeight * 0.55
                    let expandedPos: CGFloat = 0
                    
                    VStack(spacing: 0) {
                        
                        // منطقة المقبض (Header)
                        VStack(spacing: 10) {
                            Capsule()
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 40, height: 5)
                                .padding(.top, 12)
                            
                            HStack {
                                Text("Add Manually")
                                    .font(.headline)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 25)
                            .padding(.bottom, 15)
                        }
                        .background(Color.themeBackground)
                        .onTapGesture { toggleSheet(collapsedPos: collapsedPos, expandedPos: expandedPos) }
                        
                        // القائمة (ScrollView)
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(manualDevices) { device in
                                    ManualDeviceCard(device: device)
                                        .onTapGesture {
                                            selectedDevice = device
                                            showSetupWizard = true
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                        // ⚠️ التعديل الجوهري 1: شلنا الـ disabled عشان الكروت تضل شغالة
                        // واستخدمنا simultaneousGesture عشان السحب يشتغل مع السكرول
                    }
                    .frame(height: cardHeight)
                    .background(Color.themeBackground)
                    .clipShape(CustomCorner(radius: 35, corners: [.topLeft, .topRight]))
                    .shadow(color: .black.opacity(0.1), radius: 20, y: -5)
                    .offset(y: currentOffset)
                    // ⚠️ التعديل الجوهري 2: استخدام simultaneousGesture لمنع "المقاومة"
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                let newOffset = lastOffset + value.translation.height
                                // حركة حرة تماماً (1:1) بدون قسمة ولا مقاومة إلا عند الحدود القصوى
                                if newOffset < expandedPos {
                                    // فقط عند تجاوز الحد العلوي نضيف مقاومة بسيطة
                                    currentOffset = expandedPos + (newOffset / 3)
                                } else {
                                    currentOffset = newOffset
                                }
                            }
                            .onEnded { value in
                                let velocity = value.predictedEndTranslation.height
                                let threshold = collapsedPos / 2
                                
                                // منطق الفتح والإغلاق (Snap)
                                if velocity < -150 || currentOffset < threshold {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        currentOffset = expandedPos
                                    }
                                    lastOffset = expandedPos
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        currentOffset = collapsedPos
                                    }
                                    lastOffset = collapsedPos
                                }
                            }
                    )
                    .onAppear {
                        if !isOffsetInitialized {
                            currentOffset = collapsedPos
                            lastOffset = collapsedPos
                            isOffsetInitialized = true
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedDevice) { device in
                DeviceSetupWizard(device: device)
            }
        }
    }
    
    // MARK: - Logic Helpers
    func toggleSheet(collapsedPos: CGFloat, expandedPos: CGFloat) {
        let target = (currentOffset > collapsedPos / 2) ? expandedPos : collapsedPos
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            currentOffset = target
        }
        lastOffset = target
    }
    
    func calculateOpacity(totalHeight: CGFloat) -> Double {
        let progress = 1 - (currentOffset / (totalHeight * 0.5))
        return max(0.3, min(1.0, 1.0 - (progress * 0.7)))
    }
    
    // MARK: - Subviews (الرادار)
    var radarContent: some View {
        VStack {
            ZStack {
                if scanTimedOut {
                    VStack(spacing: 5) {
                        Text("No Devices Found").font(.title2).bold().foregroundColor(.textPrimary)
                        Text("Check pairing mode & try again").font(.subheadline).foregroundColor(.textSecondary)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                } else {
                    VStack(spacing: 5) {
                        Text(bleManager.isScanning ? "Scanning..." : "Add New Device")
                            .font(.title2).bold().foregroundColor(.textPrimary)
                            .contentTransition(.numericText())
                        
                        if !bleManager.isScanning {
                            Text("Bring device close to phone")
                                .font(.subheadline).foregroundColor(.textSecondary)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: scanTimedOut)
            .animation(.easeInOut(duration: 0.4), value: bleManager.isScanning)
            .padding(.bottom, 30)
            
            ZStack {
                if bleManager.isScanning { PulsingRadarView().transition(.opacity) }
                if showShockwave {
                    Circle().stroke(Color.mainPurple.opacity(0.3), lineWidth: 2)
                        .scaleEffect(3).opacity(0)
                        .onAppear { withAnimation(.easeOut(duration: 0.8)) { } }
                }
                
                if let peripheral = bleManager.foundPeripheral {
                    foundDeviceCard(name: peripheral.name ?? "Unknown Device")
                        .transition(.scale(scale: 0.8).combined(with: .opacity)).zIndex(3)
                }
                else if scanTimedOut {
                    Button(action: startScanSequence) {
                        HStack(spacing: 10) { Image(systemName: "arrow.clockwise"); Text("Scan Again") }
                            .font(.headline).foregroundColor(.white).padding(.vertical, 16).padding(.horizontal, 32)
                            .background(Color.mainPurple).clipShape(Capsule())
                            .shadow(color: .mainPurple.opacity(0.4), radius: 15, y: 8)
                            .matchedGeometryEffect(id: "CenterButton", in: animationSpace)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
                else if !bleManager.isScanning {
                    Button(action: startScanSequence) {
                        VStack(spacing: 5) {
                            Image(systemName: "dot.radiowaves.left.and.right").font(.title2)
                            Text("thakiScan").font(.headline)
                        }
                        .foregroundColor(.white).frame(width: 140, height: 140)
                        .background(ZStack {
                            Circle().fill(LinearGradient(colors: [.mainPurple, .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: 1).scaleEffect(1.2).opacity(0.5)
                        })
                        .shadow(color: .mainPurple.opacity(0.4), radius: 20, x: 0, y: 10)
                        .matchedGeometryEffect(id: "CenterButton", in: animationSpace)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                else {
                    Circle().fill(Color.mainPurple).frame(width: 20, height: 20)
                        .matchedGeometryEffect(id: "CenterButton", in: animationSpace).zIndex(2)
                }
            }
            .frame(height: 250)
        }
    }
    
    // MARK: - Logic Helper Functions
    func startScanSequence() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            scanTimedOut = false; bleManager.foundPeripheral = nil; showShockwave = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { bleManager.startScanning() }
            withAnimation(.easeOut(duration: 0.5)) { showShockwave = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            if bleManager.isScanning && bleManager.foundPeripheral == nil {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    bleManager.stopScanning(); scanTimedOut = true; showShockwave = false
                }
            }
        }
    }
    
    func foundDeviceCard(name: String) -> some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 50)).foregroundColor(.green)
                .background(Circle().fill(Color.white).frame(width: 55, height: 55))
            Text("Device Found!").font(.headline).foregroundColor(.green)
            Text(name).font(.title3).bold().foregroundColor(.textPrimary)
            Button("Setup Device") { }.bold().foregroundColor(.white)
                .padding(.vertical, 10).padding(.horizontal, 30)
                .background(Color.mainPurple).cornerRadius(20)
        }
        .padding(25).background(Color.cardBackground).cornerRadius(25)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}

// ✅ ManualDeviceCard المعدل: (Buy و Setup بنفس الحجم والتصميم)
struct ManualDeviceCard: View {
    let device: ManualDeviceItem
    let cardHeight: CGFloat = 160
    let iconSize: CGFloat = 24

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12) {
                // الجزء العلوي (أيقونة واسم)
                HStack {
                    ZStack {
                        Circle().fill(device.color.opacity(0.15))
                            .frame(width: 45, height: 45)
                        Image(systemName: device.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(device.color)
                    }
                    Spacer()
                    Image(systemName: "plus").font(.caption).foregroundColor(.gray.opacity(0.5))
                }
                
                Text(device.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(height: 40, alignment: .topLeading)
            }
            .padding(16)
            
            // الجزء السفلي (الأزرار متطابقة الحجم)
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    
                    // ✅ زر Buy (نفس تصميم Setup بالضبط لكن لون النص أخضر)
                    Link(destination: URL(string: "https://google.com")!) {
                        Text("Buy")
                            .font(.caption2).bold()
                            .foregroundColor(.green) // لون مميز للنص فقط
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .frame(minWidth: 50) // تثبيت العرض الأدنى ليطابق Setup
                            .background(Color.gray.opacity(0.1)).cornerRadius(6)
                    }
                    
                    Spacer()
                    
                    // زر Setup
                    Text("Setup")
                        .font(.caption2).bold().foregroundColor(.textSecondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .frame(minWidth: 50)
                        .background(Color.gray.opacity(0.1)).cornerRadius(6)
                }
                .padding(16)
            }
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(20)
        // ✅ الكرت كامل قابل للنقر (Hit Test يعمل)
        .contentShape(Rectangle())
    }
}

// CustomCorner, ScaleButtonStyle, PulsingRadarView, ManualDeviceItem كما هم...
struct CustomCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct PulsingRadarView: View {
    @State private var isAnimating = false
    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                Circle().stroke(LinearGradient(colors: [.mainPurple.opacity(0.6), .clear], startPoint: .center, endPoint: .topLeading), lineWidth: 2)
                    .scaleEffect(isAnimating ? 4 : 0.5).opacity(isAnimating ? 0 : 1)
                    .animation(Animation.easeOut(duration: 3).repeatForever(autoreverses: false).delay(Double(i) * 0.7), value: isAnimating)
            }
            Circle().fill(Color.mainPurple.opacity(0.2)).frame(width: 50, height: 50).blur(radius: 10)
        }.onAppear { isAnimating = true }
    }
}

struct ManualDeviceItem: Identifiable {
    let id = UUID()
    let name: String; let icon: String; let color: Color; let type: DeviceTypeForAdd
}
