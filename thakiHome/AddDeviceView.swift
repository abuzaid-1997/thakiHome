//
//  AddDeviceView.swift
//  thakiHome
//
//  Created by Mohamad Abuzaid on 09/01/2026.


import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Add Device View (Original Logic + Dark Mode Support)
struct AddDeviceView: View {
    @State private var isScanning = false
    @State private var scanFinished = false
    @State private var showManualSetup = false
    @State private var selectedDeviceType: DeviceTypeForAdd? // تأكد إن هذا الـ Enum معرف عندك

    // القائمة كما هي
    let manualDevices = [
        AddableDevice(name: "Smart Light", icon: "lightbulb.fill", type: .light),
        AddableDevice(name: "Smart Fan", icon: "fanblades.fill", type: .fan),
        AddableDevice(name: "AC Controller", icon: "snowflake", type: .ac),
        AddableDevice(name: "Motion Sensor", icon: "sensor.tag.radiowaves.forward.fill", type: .sensor)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                   
                    // 📡 منطقة الرادار التفاعلية
                    ZStack {
                        // الخلفية المتدرجة (صارت تستخدم اللون الذكي)
                        LinearGradient(
                            colors: [.mainPurple, .mainPurple.opacity(0.6)], // ✅ ذكي
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        if isScanning {
                            RadarAnimation()
                        }
                        
                        VStack {
                            Spacer()
                            if isScanning {
                                VStack(spacing: 15) {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                        .scaleEffect(1.1)
                                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isScanning)
                                   
                                    Text("Scanning for devices...")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            } else {
                                Button(action: startScan) {
                                    VStack(spacing: 5) {
                                        Image(systemName: "dot.radiowaves.left.and.right")
                                            .font(.largeTitle)
                                        Text("Smart Scan")
                                            .font(.title3).bold()
                                    }
                                    .foregroundColor(.mainPurple) // ✅ ذكي
                                    .frame(width: 130, height: 130)
                                    .background(Color.cardBackground) // ✅ ذكي (يصير رمادي بالليل)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.15), radius: 10)
                                }
                            }
                            Spacer()
                        }
                    }
                    .frame(height: 280)
                    .mask(RoundedRectangle(cornerRadius: 25, style: .continuous))
                    .padding(.horizontal)
                    .shadow(color: .mainPurple.opacity(0.3), radius: 10, y: 5) // ظل خفيف للرادار

                    // 🛠 خيار الإعداد اليدوي
                    if !isScanning {
                        VStack(spacing: 15) {
                            Text("Device not found?")
                                .font(.subheadline).foregroundColor(.textSecondary) // ✅ ذكي
                            
                            Button(action: { showManualSetup = true }) {
                                Text("Setup Manually (AP Mode)")
                                    .fontWeight(.bold)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.mainPurple) // ✅ ذكي
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 30)
                        }
                    }

                    // 📋 القائمة اليدوية للأصناف
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Select Device Category")
                            .font(.title3).bold()
                            .foregroundColor(.textPrimary) // ✅ ذكي
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 15)], spacing: 15) {
                            ForEach(manualDevices) { device in
                                Button(action: { selectedDeviceType = device.type }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: device.icon)
                                            .font(.title)
                                            .foregroundColor(.mainPurple) // ✅ ذكي
                                        Text(device.name)
                                            .font(.subheadline).bold()
                                            .foregroundColor(.textPrimary) // ✅ ذكي
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.cardBackground) // ✅ ذكي
                                    .cornerRadius(20)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2)
                                }
                            }
                        }.padding(.horizontal)
                    }
                }
                .padding(.bottom, 50)
            }
            .background(Color.themeBackground.ignoresSafeArea()) // ✅ الخلفية الرئيسية
            .navigationBarHidden(true)
            .sheet(isPresented: $showManualSetup) {
                ManualSetupWizard(selectedDeviceType: selectedDeviceType)
            }
        }
    }

    func startScan() {
        withAnimation(.spring()) { isScanning = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.spring()) { isScanning = false }
        }
    }
}

// MARK: - مكونات الأنيميشن والموديل (المفقودة سابقاً)

struct RadarAnimation: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    .scaleEffect(scale + CGFloat(i) * 0.5)
                    .opacity(opacity - Double(i) * 0.3)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                scale = 2.0
                opacity = 0.0
            }
        }
    }
}


struct ManualSetupWizard: View {
    @Environment(\.presentationMode) var presentationMode
    var selectedDeviceType: DeviceTypeForAdd?
    
    // خطوات الويزارد: 1=واي فاي, 2=ماك, 3=تخصيص
    @State private var step = 1
    
    // مدخلات المستخدم
    @State private var manualMacInput = ""
    @State private var customName = ""
    @State private var selectedRoom = "Living Room"
    @State private var addToDashboard = true
    
    // حالات التحميل
    @State private var isLinking = false
    @State private var linkError: String?
    @State private var success = false

    // قائمة الغرف المقترحة (Drop Down)
    let rooms = ["Living Room", "Bedroom", "Kitchen", "Entrance", "Office", "Bathroom", "Garden", "Other"]

    var body: some View {
        VStack(spacing: 20) {
            // شريط التقدم البسيط
            HStack {
                Circle().fill(step >= 1 ? Color(hex: "440072") : Color.gray.opacity(0.3)).frame(width: 10)
                Rectangle().fill(step >= 2 ? Color(hex: "440072") : Color.gray.opacity(0.3)).frame(height: 2)
                Circle().fill(step >= 2 ? Color(hex: "440072") : Color.gray.opacity(0.3)).frame(width: 10)
                Rectangle().fill(step >= 3 ? Color(hex: "440072") : Color.gray.opacity(0.3)).frame(height: 2)
                Circle().fill(step >= 3 ? Color(hex: "440072") : Color.gray.opacity(0.3)).frame(width: 10)
            }
            .padding(.top, 20)
            .padding(.horizontal, 50)
            
            if step == 1 {
                // --- الخطوة 1: تعليمات الاتصال ---
                stepOneView
            } else if step == 2 {
                // --- الخطوة 2: إدخال الماك ---
                stepTwoView
            } else if step == 3 {
                // --- الخطوة 3: التخصيص (الاسم والغرفة) ---
                if success {
                    successView
                } else {
                    stepThreeConfigView
                }
            }
            
            Spacer()
            
            // أزرار التنقل السفلية
            if !success {
                if step == 3 && isLinking {
                    // إخفاء الأزرار أثناء التحميل
                } else {
                    HStack {
                        if step > 1 {
                            Button("Back") { withAnimation { step -= 1 } }
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if step == 3 {
                            Button(action: finalizeSetup) {
                                Text(isLinking ? "Saving..." : "Finish")
                                    .bold()
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 30)
                                    .background(Color(hex: "440072"))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(isLinking || customName.isEmpty)
                        }
                    }
                    .padding()
                }
            } else {
                Button("Done") { presentationMode.wrappedValue.dismiss() }
                    .buttonStyle(.borderedProminent).tint(.green).padding()
            }
        }
    }

    // MARK: - Subviews (مكونات الواجهة)
    
    var stepOneView: some View {
        ScrollView {
            VStack(spacing: 25) {
                Image(systemName: "wifi.square.fill")
                    .font(.system(size: 70)).foregroundColor(Color(hex: "440072"))
                Text("Connect Device").font(.title2).bold()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("1. Connect to 'thakiHome-Setup' WiFi.").font(.subheadline)
                    Text("2. Configure your network.").font(.subheadline)
                    Text("3. Copy the Device ID shown on screen.").font(.subheadline).bold()
                }
                .padding().background(Color.gray.opacity(0.05)).cornerRadius(12)
                
                Button(action: openSettings) {
                    HStack { Text("Open WiFi Settings"); Spacer(); Image(systemName: "arrow.up.right") }
                        .padding().background(Color(hex: "440072").opacity(0.1)).cornerRadius(10)
                }.padding(.horizontal)
                
                Button("Next: Enter ID") { withAnimation { step = 2 } }
                    .padding().frame(maxWidth: .infinity)
                    .background(Color(hex: "440072")).foregroundColor(.white).cornerRadius(12)
                    .padding(.top)
            }.padding()
        }
    }
    
    var stepTwoView: some View {
        VStack(spacing: 25) {
            Text("Enter Device ID").font(.title2).bold()
            Text("Paste the ID (MAC Address) from the setup page.").font(.caption).foregroundColor(.gray)
            
            HStack {
                Image(systemName: "barcode.viewfinder").foregroundColor(.gray)
                TextField("Ex: 84:CC:A8:...", text: $manualMacInput)
                    .font(.system(.body, design: .monospaced))
                
                if UIPasteboard.general.hasStrings {
                    Button("Paste") {
                        if let string = UIPasteboard.general.string { manualMacInput = string }
                    }.font(.caption).bold().foregroundColor(Color(hex: "440072"))
                }
            }
            .padding().background(Color.gray.opacity(0.1)).cornerRadius(12)
            .padding(.horizontal)
            
            Button("Next: Configure") {
                let clean = manualMacInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    self.manualMacInput = clean
                    // اسم افتراضي مقترح
                    if customName.isEmpty { customName = "My \(selectedDeviceType?.rawValue.capitalized ?? "Device")" }
                    withAnimation { step = 3 }
                }
            }
            .disabled(manualMacInput.isEmpty)
            .padding().frame(maxWidth: .infinity)
            .background(manualMacInput.isEmpty ? Color.gray : Color(hex: "440072"))
            .foregroundColor(.white).cornerRadius(12).padding(.horizontal)
        }
    }
    
    var stepThreeConfigView: some View {
        ScrollView {
            VStack(spacing: 25) {
                Text("Customize Device").font(.title2).bold()
                
                // 1. الاسم
                VStack(alignment: .leading) {
                    Text("Device Name").font(.caption).foregroundColor(.gray)
                    TextField("Ex: Living Room Light", text: $customName)
                        .padding().background(Color.gray.opacity(0.1)).cornerRadius(10)
                }
                
                // 2. الغرفة (Dropdown)
                VStack(alignment: .leading) {
                    Text("Select Room").font(.caption).foregroundColor(.gray)
                    Menu {
                        ForEach(rooms, id: \.self) { room in
                            Button(room) { selectedRoom = room }
                        }
                    } label: {
                        HStack {
                            Text(selectedRoom).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down").foregroundColor(.gray)
                        }
                        .padding().background(Color.gray.opacity(0.1)).cornerRadius(10)
                    }
                }
                
                // 3. الداشبورد
                Toggle(isOn: $addToDashboard) {
                    VStack(alignment: .leading) {
                        Text("Add to Dashboard").bold()
                        Text("Show in favorites").font(.caption).foregroundColor(.gray)
                    }
                }
                .padding().background(Color.gray.opacity(0.05)).cornerRadius(10)
                
                if let error = linkError {
                    Text(error).foregroundColor(.red).font(.caption)
                }
                
                if isLinking {
                    ProgressView().padding()
                }
            }
            .padding()
        }
    }
    
    var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80)).foregroundColor(.green)
            Text("All Set!").font(.title).bold()
            Text("Your device is ready in **\(selectedRoom)**").foregroundColor(.gray)
        }
    }

    // MARK: - Functions
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func finalizeSetup() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        isLinking = true
        let db = Firestore.firestore()
        let docRef = db.collection("devices").document(manualMacInput)
        
        docRef.getDocument { (document, error) in
            // البيانات التي سيدخلها المستخدم
            let updateData: [String: Any] = [
                "ownerEmail": userEmail,
                "name": customName,      // الاسم من المستخدم
                "room": selectedRoom,    // الغرفة من القائمة
                "showOnDashboard": addToDashboard,
                "online": true
            ]
            
            if let document = document, document.exists {
                // ✅ الجهاز موجود (من المصنع): نحدث فقط البيانات الوصفية + المالك
                // بنحافظ على الـ "type" والـ "icon" اللي جايين من المصنع
                docRef.updateData(updateData) { error in
                    handleResult(error)
                }
            } else {
                // ⚠️ الجهاز غير موجود: ننشئه (Fallback)
                var newData = updateData
                newData["mac"] = manualMacInput
                newData["type"] = selectedDeviceType?.rawValue ?? "unknown"
                newData["addedAt"] = FieldValue.serverTimestamp()
                
                docRef.setData(newData, merge: true) { error in
                    handleResult(error)
                }
            }
        }
    }
    
    func handleResult(_ error: Error?) {
        isLinking = false
        if let error = error {
            linkError = error.localizedDescription
        } else {
            withAnimation { success = true }
        }
    }
}

// تصميم السطر الواحد للتعليمات
struct InstructionRow: View {
    let num: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Text(num)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color(hex: "440072")))
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct WizardStepView: View {
    let image: String; let title: String; let desc: String
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: image).font(.system(size: 80)).foregroundColor(Color(hex: "440072"))
            Text(title).font(.title2).bold()
            Text(desc).multilineTextAlignment(.center).foregroundColor(.gray).padding(.horizontal)
        }
    }
}

struct AddableDevice: Identifiable {
    let id = UUID(); let name: String; let icon: String; let type: DeviceTypeForAdd
}

enum DeviceTypeForAdd: String, Identifiable {
    case light, fan, waterTank, ac, sensor
    var id: String { self.rawValue }
}
