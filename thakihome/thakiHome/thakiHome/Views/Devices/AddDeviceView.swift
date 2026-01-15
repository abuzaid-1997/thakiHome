import SwiftUI

struct AddDeviceView: View {
    @StateObject private var bleManager = BluetoothManager()
    @State private var showSetupWizard = false
    @State private var selectedDevice: ManualDeviceItem?
    @State private var scanTimedOut = false
    
    // للتحكم بالأنيميشن الدقيق
    @Namespace private var animationSpace
    @State private var showShockwave = false // موجة الانفجار عند البدء
    
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
            ZStack {
                LinearGradient(
                    colors: [Color.mainPurple.opacity(0.12), Color.themeBackground],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // MARK: - 1. Radar & Interaction Area
                    VStack {
                        Spacer()
                        
                        // نصوص الحالة (Text Morphing)
                        ZStack {
                            if scanTimedOut {
                                VStack(spacing: 5) {
                                    Text("No Devices Found")
                                        .font(.title2).bold().foregroundColor(.textPrimary)
                                    Text("Check pairing mode & try again")
                                        .font(.subheadline).foregroundColor(.textSecondary)
                                }
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                            } else {
                                VStack(spacing: 5) {
                                    Text(bleManager.isScanning ? "Scanning..." : "Add New Device")
                                        .font(.title2).bold().foregroundColor(.textPrimary)
                                        // هذا الـ ID يخلي SwiftUI يفهم إنه نفس النص بس تغير محتواه فيعمل Morph
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
                        .padding(.bottom, 40)
                        
                        // منطقة الأكشن (الزر والرادار)
                        ZStack {
                            
                            // 1. الرادار (يظهر فقط عند المسح)
                            if bleManager.isScanning {
                                PulsingRadarView()
                                    .transition(.opacity)
                            }
                            
                            // 2. موجة الانفجار (Shockwave Effect)
                            if showShockwave {
                                Circle()
                                    .stroke(Color.mainPurple.opacity(0.3), lineWidth: 2)
                                    .scaleEffect(3)
                                    .opacity(0)
                                    .onAppear {
                                        withAnimation(.easeOut(duration: 0.8)) {
                                            // أنيميشن لمرة واحدة عند البدء
                                        }
                                    }
                            }
                            
                            if let peripheral = bleManager.foundPeripheral {
                                // 3. تم العثور على جهاز
                                foundDeviceCard(name: peripheral.name ?? "Unknown Device")
                                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                                    .zIndex(3)
                            }
                            else if scanTimedOut {
                                // 4. زر المحاولة مجدداً (يظهر من قلب الرادار)
                                Button(action: startScanSequence) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.headline)
                                        Text("Scan Again")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 32)
                                    .background(Color.mainPurple)
                                    .clipShape(Capsule())
                                    .shadow(color: .mainPurple.opacity(0.4), radius: 15, y: 8)
                                    .matchedGeometryEffect(id: "CenterButton", in: animationSpace)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                            }
                            else if !bleManager.isScanning {
                                // 5. زر البدء الرئيسي thakiScan
                                Button(action: startScanSequence) {
                                    VStack(spacing: 5) {
                                        Image(systemName: "dot.radiowaves.left.and.right")
                                            .font(.title2)
                                        Text("thakiScan")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .frame(width: 140, height: 140)
                                    .background(
                                        ZStack {
                                            // خلفية الزر المتدرجة
                                            Circle()
                                                .fill(LinearGradient(colors: [.mainPurple, .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                .shadow(color: .mainPurple.opacity(0.4), radius: 20, x: 0, y: 10)
                                            
                                            // حلقات خفيفة توحي بالتنفس (Breathing)
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                .scaleEffect(1.2)
                                                .opacity(0.5)
                                        }
                                    )
                                    .matchedGeometryEffect(id: "CenterButton", in: animationSpace)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                            else {
                                // 6. نقطة الارتكاز أثناء المسح (عشان التحول يكون ناعم)
                                Circle()
                                    .fill(Color.mainPurple)
                                    .frame(width: 20, height: 20)
                                    .matchedGeometryEffect(id: "CenterButton", in: animationSpace)
                                    .zIndex(2)
                            }
                        }
                        .frame(height: 250) // حجز مساحة ثابتة للأنيميشن
                        
                        Spacer()
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.45)
                    
                    // MARK: - 2. Manual List
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Add Manually")
                                .font(.headline).foregroundColor(.textPrimary)
                            Spacer()
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 25)
                        
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
                            .padding(.bottom, 40)
                        }
                    }
                    .background(Color.themeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 35, style: .continuous))
                    .shadow(color: .black.opacity(0.03), radius: 15, y: -5)
                    .ignoresSafeArea(.all, edges: .bottom)
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedDevice) { device in
                DeviceSetupWizard(device: device)
            }
        }
    }
    
    // MARK: - Logic & Animation Control
    
    func startScanSequence() {
        // 1. إعادة تعيين الحالات
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            scanTimedOut = false
            bleManager.foundPeripheral = nil
            showShockwave = false
        }
        
        // 2. تشغيل الـ Shockwave والمسح بتزامن دقيق
        // نعطي وقت قصير للزر عشان "ينضغط" قبل ما ينفجر
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            
            // A. تشغيل الرادار
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                bleManager.startScanning()
            }
            
            // B. تشغيل موجة الانفجار
            withAnimation(.easeOut(duration: 0.5)) {
                showShockwave = true
            }
        }
        
        // 3. إنهاء المسح (محاكاة)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { // قللت الوقت للتجربة
            if bleManager.isScanning && bleManager.foundPeripheral == nil {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    bleManager.stopScanning()
                    scanTimedOut = true
                    showShockwave = false
                }
            }
        }
    }
    
    // كرت الجهاز الموجود
    func foundDeviceCard(name: String) -> some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
                .background(Circle().fill(Color.white).frame(width: 55, height: 55))
            
            Text("Device Found!")
                .font(.headline).foregroundColor(.green)
            
            Text(name)
                .font(.title3).bold().foregroundColor(.textPrimary)
            
            Button("Setup Device") { }
                .bold().foregroundColor(.white)
                .padding(.vertical, 10).padding(.horizontal, 30)
                .background(Color.mainPurple).cornerRadius(20)
        }
        .padding(25)
        .background(Color.cardBackground)
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Components

// ✅ 1. زر نابض عند الضغط (Scale Button)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0) // انكماش ملحوظ
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// ✅ 2. رادار "مذهل" (Pulsing Gradient Radar)
struct PulsingRadarView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // حلقات متعددة بتوقيتات مختلفة
            ForEach(0..<4) { i in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.mainPurple.opacity(0.6), .clear],
                            startPoint: .center,
                            endPoint: .topLeading
                        ),
                        lineWidth: 2
                    )
                    .scaleEffect(isAnimating ? 4 : 0.5) // تكبير ضخم
                    .opacity(isAnimating ? 0 : 1)       // اختفاء تدريجي
                    .animation(
                        Animation.easeOut(duration: 3)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.7), // تأخير بين كل حلقة
                        value: isAnimating
                    )
            }
            
            // وهج في المركز
            Circle()
                .fill(Color.mainPurple.opacity(0.2))
                .frame(width: 50, height: 50)
                .blur(radius: 10)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// ✅ 3. كرت الجهاز (Manual Device Card) - نفس اللي اعتمدناه سابقاً
struct ManualDeviceCard: View {
    let device: ManualDeviceItem
    let cardHeight: CGFloat = 160
    let iconSize: CGFloat = 24

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12) {
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
            
            VStack {
                Spacer()
                HStack {
                    Text("Setup")
                        .font(.caption2).bold().foregroundColor(.textSecondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1)).cornerRadius(6)
                    Spacer()
                }
                .padding(16)
            }
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .contentShape(Rectangle())
    }
}

// ✅ 4. داتا موديل (Manual Device Item)
struct ManualDeviceItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let type: DeviceTypeForAdd
}
