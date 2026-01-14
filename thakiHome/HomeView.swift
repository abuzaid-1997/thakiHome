import SwiftUI
import FirebaseFirestore

// MARK: - 1. HomeView Main
struct HomeView: View {
    @Binding var isLoggedIn: Bool
    @State private var selectedTab = 0
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isEditing = false
    @Namespace private var animation
    
    // متغير لفتح صفحة التفاصيل
    @State private var selectedDeviceForDetails: DeviceItem?
    
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            GeometryReader { geometry in
                let width = geometry.size.width
                
                ZStack(alignment: .bottom) {
                    
                    ZStack(alignment: .leading) {
                        HStack(spacing: 0) {
                            // صفحة الداشبورد
                            DashboardView(devices: $viewModel.devices, isEditing: $isEditing, viewModel: viewModel, onShowDetails: { dev in selectedDeviceForDetails = dev })
                                .frame(width: width)
                            
                            // صفحة كل الأجهزة
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
                            .onChanged { dragOffset = $0.translation.width }
                            .onEnded { value in
                                let threshold = width * 0.2
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if value.translation.width < -threshold && currentPage == 0 { currentPage = 1 }
                                    else if value.translation.width > threshold && currentPage == 1 { currentPage = 0 }
                                    dragOffset = 0
                                }
                            }
                    )

                    // التبويبات السفلية العائمة (Dashboard / All Devices)
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
            // خلفية التطبيق الذكية (غامقة بالليل)
            .background(Color.themeBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            
            // Sheet التفاصيل (يفتح عند اختيار جهاز)
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

// MARK: - 2. Dashboard View
struct DashboardView: View {
    @Binding var devices: [DeviceItem]
    @Binding var isEditing: Bool
    var viewModel: HomeViewModel
    var onShowDetails: (DeviceItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("My Home").font(.largeTitle).bold().foregroundColor(.mainPurple).padding(.horizontal)
                
                // تصفية الأجهزة للداشبورد فقط
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
                    // محرك الترتيب الذكي
                    AdvancedLayoutEngine(
                        devices: $devices,
                        viewModel: viewModel, // ✅ تم تمرير viewModel هنا
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

// MARK: - 3. All Devices View
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
                    Text("No devices found").padding()
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
                                        .onLongPressGesture(minimumDuration: 0.6, perform: {
                                            stopHaptic()
                                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                                            generator.impactOccurred(intensity: 1.0)
                                            onShowDetails(d)
                                        }) { isPressing in
                                            if isPressing { startContinuousHaptic() } else { stopHaptic() }
                                        }
                                }
                            }.padding(.horizontal)
                        }
                    }
                }
            }.padding(.top, 60).padding(.bottom, 120)
        }
    }
    
    func startContinuousHaptic() {
        hapticTimer?.invalidate()
        hapticIntensity = 0.0
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            hapticIntensity += 0.05
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: min(hapticIntensity, 1.0))
        }
    }
    
    func stopHaptic() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        hapticIntensity = 0.0
    }
}

// MARK: - 4. Advanced Layout Engine
struct AdvancedLayoutEngine: View {
    @Binding var devices: [DeviceItem]
    var viewModel: HomeViewModel // ✅ إضافة هذا المتغير
    var isEditing: Bool
    var onShowDetails: (DeviceItem) -> Void
    var onResize, onDelete: (DeviceItem)->Void
    var onStart: ()->Void
    var onToggle: (DeviceItem)->Void

    @State private var hapticIntensity: CGFloat = 0.0
    @State private var hapticTimer: Timer?

    var body: some View {
        VStack(spacing: 15) {
            let visibleDevices = devices.filter { $0.safeShowOnDashboard }
            
            let chunks = splitIntoChunks(devices: visibleDevices)
            ForEach(0..<chunks.count, id: \.self) { i in
                if chunks[i].full {
                    ForEach(chunks[i].items) { d in cardView(d) }
                } else {
                    HStack(alignment: .top, spacing: 15) {
                        VStack(spacing: 15) { ForEach(chunks[i].left) { d in cardView(d) } }.frame(maxWidth: .infinity)
                        VStack(spacing: 15) { ForEach(chunks[i].right) { d in cardView(d) } }.frame(maxWidth: .infinity)
                    }.padding(.horizontal)
                }
            }
        }
        .onDisappear { stopHaptic() }
        .onChange(of: isEditing) { oldValue, newValue in
            if newValue { stopHaptic() }
        }
    }
    
    func cardView(_ d: DeviceItem) -> some View {
        // ✅ استخدام DraggableCard الجديدة وتمرير viewModel
        DraggableCard(d: d, edit: isEditing, viewModel: viewModel, del: onDelete, start: onStart)
            .padding(d.safeSize == .wide || d.safeSize == .big ? .horizontal : [])
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditing {
                    onToggle(d)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
            .onLongPressGesture(minimumDuration: 0.6, perform: {
                if isEditing { return }
                stopHaptic()
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred(intensity: 1.0)
                onShowDetails(d)
            }) { isPressing in
                if isEditing { return }
                if isPressing { startContinuousHaptic() } else { stopHaptic() }
            }
    }
    
    func startContinuousHaptic() {
        guard !isEditing else { return }
        stopHaptic()
        hapticIntensity = 0.0
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            hapticIntensity += 0.05
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: min(hapticIntensity, 1.0))
        }
    }
    
    func stopHaptic() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        hapticIntensity = 0.0
    }

    struct Chunk { var full: Bool; var items, left, right: [DeviceItem] }
    func splitIntoChunks(devices: [DeviceItem]) -> [Chunk] {
        var res: [Chunk] = []; var buf: [DeviceItem] = []
        for d in devices {
            if d.safeSize == .wide || d.safeSize == .big {
                if !buf.isEmpty { res.append(makeChunk(buf)); buf = [] }
                res.append(Chunk(full: true, items: [d], left: [], right: []))
            } else { buf.append(d) }
        }
        if !buf.isEmpty { res.append(makeChunk(buf)) }
        return res
    }
    func makeChunk(_ items: [DeviceItem]) -> Chunk {
        var l: [DeviceItem] = [], r: [DeviceItem] = []
        for (i, d) in items.enumerated() { if i % 2 == 0 { l.append(d) } else { r.append(d) } }
        return Chunk(full: false, items: [], left: l, right: r)
    }
}

// MARK: - 5. Draggable Card (الترتيب: كرت -> شبح -> أزرار)
struct DraggableCard: View {
    let d: DeviceItem
    let edit: Bool
    var viewModel: HomeViewModel
    var del: (DeviceItem)->Void
    var start: ()->Void
    
    @State private var dragTranslation: CGSize = .zero
    @State private var predictedSize: CardSize? = nil
    
    // متغير محلي للتحكم بالهزة
    @State private var isJiggling = false
    
    var body: some View {
        // الحاوية الرئيسية (تجمع الكل وتهتز)
        ZStack(alignment: .topLeading) {
            
            // ---------------------------------------------
            // طبقة 1: الكرت الأصلي (في الأسفل) ⬇️
            // ---------------------------------------------
            ZStack {
                            // إذا كان الجهاز حساس خزان، اعرض كرت الخزان
                            if d.type == "water_sensor" {
                                WaterTankCard(d: d)
                            } else {
                                // باقي الأجهزة العادية
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.cardBackground)
                                    .shadow(color: Color.black.opacity(0.05), radius: 6, y: 4)
                                
                                if d.safeSize == .small { SmallContent(d: d) }
                                else if d.safeSize == .wide { WideContent(d: d) }
                                else if d.safeSize == .tall { TallContent(d: d) }
                                else { BigContent(d: d) }
                            }
                        }
            .frame(width: frameSize(for: d.safeSize).width, height: frameSize(for: d.safeSize).height)
            
            // ---------------------------------------------
            // طبقة 2: شبح المعاينة (فوق الكرت، تحت الأزرار) ↔️
            // ---------------------------------------------
            if let targetSize = predictedSize, edit {
                ZStack {
                    // لون خلفية خفيف جداً يغطي الكرت الأصلي ليوضح التغيير
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.mainPurple.opacity(0.08)) // شفافية عالية
                    
                    // الإطار المنقط (Outline)
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.mainPurple, style: StrokeStyle(lineWidth: 3, dash: [8]))
                }
                .frame(width: frameSize(for: targetSize).width, height: frameSize(for: targetSize).height)
                // هذا يضمن أن الشبح يظهر فوق الكرت الأصلي
                .zIndex(50)
            }

            // ---------------------------------------------
            // طبقة 3: أزرار التحكم (فوق الجميع دائماً) ⬆️
            // ---------------------------------------------
            if edit {
                // A. مقبض السحب (زاوية يمين تحت)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.mainPurple))
                            .padding(6)
                            .shadow(radius: 2)
                            // 👇 الجيستشر هنا عشان الزر هو اللي يستقبل اللمس
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if isJiggling { isJiggling = false } // نوقف الهزة عشان التركيز
                                        dragTranslation = value.translation
                                        calculatePredictedSize()
                                    }
                                    .onEnded { value in
                                        if let target = predictedSize {
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                viewModel.setDeviceSize(d, size: target)
                                            }
                                        }
                                        dragTranslation = .zero
                                        predictedSize = nil
                                        
                                        // إعادة الهزة
                                        if edit {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                isJiggling = true
                                            }
                                        }
                                    }
                            )
                    }
                }
                // نتأكد إن إطار الأزرار دائماً بحجم الكرت الأصلي (عشان مكان الزر ما يضيع)
                .frame(width: frameSize(for: d.safeSize).width, height: frameSize(for: d.safeSize).height)
                .zIndex(100) // 🛑 طبقة عليا
                
                // B. زر الحذف (زاوية يسار فوق)
                Button { del(d) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                        .background(Circle().fill(.white))
                        .shadow(radius: 2)
                }
                .offset(x: -8, y: -8)
                .zIndex(101) // 🛑 طبقة عليا جداً
            }
        }
        // إعدادات الحاوية والهزة
        .frame(width: frameSize(for: d.safeSize).width, height: frameSize(for: d.safeSize).height, alignment: .topLeading)
        .zIndex(predictedSize != nil ? 1000 : 0) // رفع الكرت كامل فوق الكروت المجاورة عند السحب
        .rotationEffect(.degrees(isJiggling ? 1.2 : 0)) // الهزة تطبق على الـ ZStack كامل (كرت + شبح + أزرار)
        .animation(isJiggling ? .linear(duration: 0.14).repeatForever(autoreverses: true) : .default, value: isJiggling)
        .onLongPressGesture { start() }
        .onChange(of: edit) { oldValue, newValue in isJiggling = newValue }
        .onAppear { if edit { isJiggling = true } }
    }
    
    // الدوال المساعدة (بدون تغيير)
    func calculatePredictedSize() {
        let w = dragTranslation.width
        let h = dragTranslation.height
        let sensitivity: CGFloat = 30
        if w > sensitivity && h > sensitivity { predictedSize = .big }
        else if w > sensitivity { predictedSize = .wide }
        else if h > sensitivity { predictedSize = .tall }
        else if w < -sensitivity || h < -sensitivity { predictedSize = .small }
    }
    
    func frameSize(for size: CardSize) -> CGSize {
        let baseW: CGFloat = 165
        let baseH: CGFloat = 110
        let spacing: CGFloat = 15
        switch size {
        case .small: return CGSize(width: baseW, height: baseH)
        case .wide:  return CGSize(width: (baseW * 2) + spacing, height: baseH)
        case .tall:  return CGSize(width: baseW, height: (baseH * 2) + spacing)
        case .big:   return CGSize(width: (baseW * 2) + spacing, height: (baseH * 2) + spacing)
        }
    }
}

// MARK: - 6. Content Subviews (Smart Colors)
struct SmallContent: View {
    let d: DeviceItem
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: d.safeIcon)
                    .foregroundColor(d.safeIsActive ? .mainPurple : .textSecondary)
                Spacer()
                Circle().fill(d.safeIsActive ? .green : .gray.opacity(0.3)).frame(width:8)
            }
            Spacer()
            Text(d.name).bold().lineLimit(1).font(.system(size: 15))
                .foregroundColor(.textPrimary)
            Text(d.safeStatus).font(.caption).foregroundColor(.textSecondary)
        }.padding(15)
    }
}

struct WideContent: View {
    let d: DeviceItem
    var body: some View {
        HStack {
            Image(systemName: d.safeIcon).font(.title2)
                .foregroundColor(d.safeIsActive ? .mainPurple : .textSecondary)
                .frame(width: 50)
            VStack(alignment: .leading) {
                Text(d.name).bold().foregroundColor(.textPrimary)
                Text(d.safeStatus).font(.caption).foregroundColor(.textSecondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { d.safeIsActive }, set: { _ in })).labelsHidden().disabled(true)
        }.padding()
    }
}

struct TallContent: View {
    let d: DeviceItem
    var body: some View {
        VStack {
            Image(systemName: d.safeIcon).font(.largeTitle)
                .foregroundColor(d.safeIsActive ? .mainPurple : .textSecondary)
                .padding(.top)
            Spacer()
            Text(d.name).bold().foregroundColor(.textPrimary)
            Text(d.safeStatus).bold().padding(.bottom).foregroundColor(.textSecondary)
        }.padding()
    }
}

struct BigContent: View {
    let d: DeviceItem
    var body: some View {
        VStack(alignment: .leading) {
            Image(systemName: d.safeIcon).font(.largeTitle)
                .foregroundColor(d.safeIsActive ? .mainPurple : .textSecondary)
            Spacer()
            Text(d.name).bold().foregroundColor(.textPrimary)
            Text(d.safeStatus).font(.title2).bold().foregroundColor(.textSecondary)
        }.padding(20)
    }
}

// MARK: - 8. Water Tank Components

// 🌊 1. شكل الموجة المتحركة
// 🌊 1. شكل الموجة (تم حل مشكلة الفلاش)
struct Wave: Shape {
    var offset: Angle
    var percent: Double
    
    var animatableData: Double {
        get { offset.degrees }
        set { offset = Angle(degrees: newValue) }
    }
    
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let lowestWave = 0.02
        let highestWave = 1.00
        
        let newPercent = lowestWave + (highestWave - lowestWave) * (percent / 100)
        let waveHeight = 0.015 * rect.height
        let yOffset = CGFloat(1 - newPercent) * (rect.height - 4 * waveHeight) + 2 * waveHeight
        let startAngle = offset
        let endAngle = offset + Angle(degrees: 360)
        
        // نبدأ الرسم من خارج الشاشة قليلاً (-5) لتجنب الفراغ الأبيض
        p.move(to: CGPoint(x: -5, y: yOffset + waveHeight * CGFloat(sin(offset.radians))))
        
        for angle in stride(from: startAngle.degrees, through: endAngle.degrees, by: 5) {
            let x = CGFloat((angle - startAngle.degrees) / 360) * (rect.width + 10) - 5
            p.addLine(to: CGPoint(x: x, y: yOffset + waveHeight * CGFloat(sin(Angle(degrees: angle).radians))))
        }
        
        p.addLine(to: CGPoint(x: rect.width + 5, y: rect.height))
        p.addLine(to: CGPoint(x: -5, y: rect.height))
        p.closeSubpath()
        return p
    }
}

// 🚰 2. كرت الخزان (النسخة الذكية المتصلة بالحساس)
struct WaterTankCard: View {
    let d: DeviceItem
    @State private var waveOffset = Angle(degrees: 0)
    
    // 1. قراءة المسافة الحالية (التي يرسلها الحساس)
    var currentDistance: Double {
        return Double(d.val ?? "0") ?? 0.0
    }
    
    // 2. حساب ارتفاع الماء الحالي
    var currentWaterHeight: Double {
        let sensorHeight = d.tankHeight ?? 200.0 // القيمة الافتراضية
        // ارتفاع الماء = ارتفاع السنسور - المسافة المقاسة
        let height = sensorHeight - currentDistance
        return max(0, height) // ممنوع يكون سالب
    }
    
    // 3. حساب النسبة المئوية
    var waterPercentage: Double {
        let maxLevel = d.maxWaterLevel ?? 180.0 // القيمة الافتراضية
        let percent = (currentWaterHeight / maxLevel) * 100.0
        return min(max(percent, 0), 100) // حصر النسبة بين 0 و 100
    }
    
    // 4. حساب الحجم بالمتر المكعب
    var currentVolumeM3: String {
        let totalVol = d.tankVolume ?? 4.0
        let currentVol = (waterPercentage / 100.0) * totalVol
        return String(format: "%.1f m³", currentVol)
    }
    
    // قراءة نسبة البطارية (سنفترض أنها محفوظة في حقل `status` مؤقتاً أو نضيف حقل جديد لاحقاً)
    // حالياً سنثبتها حتى نعدل كود الأردوينو ليرسلها
    var batteryLevel: Int { return 85 }
    
    var isWaterCoveringTop: Bool { return waterPercentage > 85 }
    var textColor: Color { return isWaterCoveringTop ? .white.opacity(0.9) : .gray }
    
    var body: some View {
        ZStack {
            Color.cardBackground
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    Wave(offset: waveOffset, percent: waterPercentage) // استخدام النسبة المحسوبة
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.mainPurple.opacity(0.7)]),
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
            .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: waveOffset)
            .onAppear { waveOffset = Angle(degrees: 360) }
            
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "drop.fill").font(.title3).foregroundColor(.cyan)
                    Spacer()
                    HStack(spacing: 2) {
                        Text("\(batteryLevel)%").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                        Image(systemName: "battery.75").font(.caption2).foregroundColor(.gray)
                    }
                    .padding(4).background(.ultraThinMaterial).cornerRadius(8)
                }
                Spacer()
                
                // عرض النسبة المئوية المحسوبة
                Text("\(Int(waterPercentage))%")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(waterPercentage > 40 ? .white : .textPrimary)
                    .shadow(radius: waterPercentage > 40 ? 3 : 0)
                
                Text(currentVolumeM3)
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(waterPercentage > 40 ? .white.opacity(0.9) : .textSecondary)
            }
            .padding(15)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - 7. Theme & Colors Manager (Smart Colors)
extension Color {
    // لون البراند (لافندر بالليل، بنفسجي غامق بالنهار)
    static var mainPurple: Color {
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 1.0) : UIColor(red: 0.27, green: 0.0, blue: 0.45, alpha: 1.0) })
    }
    
    // خلفية التطبيق
    static var themeBackground: Color {
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor.black : UIColor.systemGroupedBackground })
    }
    
    // خلفية الكروت (رمادي غامق بالليل، أبيض بالنهار)
    static var cardBackground: Color {
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) : UIColor.white })
    }
    
    // النصوص
    static var textPrimary: Color {
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor.white : UIColor.black })
    }
    
    static var textSecondary: Color {
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor.lightGray : UIColor.gray })
    }
}
// 🛑 تأكد أن هذا القوس الأخير موجود!
