import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct DeviceSetupWizard: View {
    @Environment(\.presentationMode) var presentationMode
    let device: ManualDeviceItem
    
    // التحكم بالخطوات
    @State private var currentStep = 0
    @State private var isAnimatingLed = false
    
    // بيانات الإدخال
    @State private var manualMacInput: String = ""
    @State private var customName: String = ""
    @State private var selectedRoom: String = "Living Room"
    
    // حالات الـ Firebase
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var saveSuccess = false
    
    let rooms = ["Living Room", "Bedroom", "Kitchen", "Bathroom", "Office", "Garden", "Roof"]
    
    // حساب عرض الأزرار
    var buttonWidth: CGFloat {
        UIScreen.main.bounds.width - 60
    }

    init(device: ManualDeviceItem) {
        self.device = device
        _customName = State(initialValue: device.name)
    }
    
    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()
            
            if saveSuccess {
                successView
            } else {
                contentView
            }
            
            // زر الإغلاق العلوي
            if !isSaving && !saveSuccess {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.gray.opacity(0.5))
                                .padding()
                        }
                    }
                    Spacer()
                }
                .zIndex(10) // عشان يضل فوق الكل
            }
            
            // شاشة التحميل
            if isSaving {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 15) {
                        ProgressView().scaleEffect(1.5).tint(.white)
                        Text("Registering Device...")
                            .font(.headline).foregroundColor(.white)
                    }
                    .padding(30)
                    .background(Color.cardBackground)
                    .cornerRadius(20)
                }
                .zIndex(20)
            }
        }
        // إغلاق الكيبورد عند لمس أي مكان
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    // MARK: - المحتوى الرئيسي
    
    var contentView: some View {
        VStack(spacing: 0) {
            
            // 1. Header (يظهر فقط في الخطوات 0 و 1)
            // في الخطوة 2 نخفيه عشان نعطي مساحة للسكرول
            if currentStep < 2 {
                ZStack {
                    ZStack {
                        Circle()
                            .fill(device.color.opacity(0.15))
                            .frame(width: 380, height: 380)
                            .offset(y: -180)
                            .blur(radius: 60)
                    }.clipped()
                    
                    VStack(spacing: 12) {
                        Image(systemName: device.icon)
                            .font(.system(size: 52))
                            .foregroundColor(device.color)
                            .padding(22)
                            .background(Circle().fill(Color.cardBackground).shadow(color: device.color.opacity(0.2), radius: 15, y: 8))
                        
                        Text(device.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 50)
                }
                .frame(height: 240)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // 2. منطقة الخطوات (TabView)
            TabView(selection: $currentStep) {
                
                // --- Step 1 ---
                stepView(
                    title: "Reset Device",
                    desc: "Press and hold the **Reset Button** on your device for 7 seconds to enter AP Mode.",
                    icon: "hand.tap.fill",
                    content: nil
                ).tag(0)
                
                // --- Step 2 ---
                stepView(
                    title: "Connect & Get ID",
                    desc: "1. Connect to **'thakiHome-Setup'** WiFi.\n2. Configure WiFi.\n3. **Copy the Device ID** shown.",
                    icon: "wifi",
                    content: AnyView(wifiInstructionContent)
                ).tag(1)
                
                // --- Step 3 (The Form) ---
                // ✅ هنا التغيير الجذري: الفورم هو صفحة كاملة قابلة للسكرول
                finalStepScrollableView
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
            
            // 3. Footer (Fixed Buttons)
            // يظهر فقط في الخطوات 0 و 1. في الخطوة 2 الزر جوا السكرول
            if currentStep < 2 {
                VStack(spacing: 20) {
                    // النقاط
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(currentStep == index ? device.color : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentStep == index ? 1.2 : 1)
                                .animation(.spring(), value: currentStep)
                        }
                    }
                    
                    // زر Next العادي
                    Button(action: handleNextStep) {
                        Text("Next Step")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: buttonWidth, height: 55)
                            .background(device.color)
                            .cornerRadius(20)
                            .shadow(color: device.color.opacity(0.4), radius: 10, y: 5)
                    }
                    .padding(.bottom, 10)
                }
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - تصميم الخطوة الأخيرة (Scrollable)
    
    // ✅ هذه الصفحة تحتوي على كل شيء (عنوان، تعليمات، حقول، وزر) داخل سكرول واحد
    var finalStepScrollableView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 25) {
                
                // مسافة علوية بديلة عن الهيدر المحذوف
                Spacer().frame(height: 40)
                
                // 1. أيقونة وعنوان صغير (يتحرك مع السكرول)
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 40))
                        .foregroundColor(device.color)
                        .padding()
                        .background(device.color.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text("Paste ID & Add")
                        .font(.title2).bold()
                        .foregroundColor(.textPrimary)
                    
                    Text("Paste the ID you copied from the device page.")
                        .font(.body)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // 2. الحقول
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "barcode.viewfinder").foregroundColor(.gray)
                        TextField("Paste Device ID here", text: $manualMacInput)
                            .font(.system(.body, design: .monospaced))
                        if UIPasteboard.general.hasStrings {
                            Button("Paste") { if let s = UIPasteboard.general.string { manualMacInput = s } }
                                .font(.caption).bold().foregroundColor(device.color)
                                .padding(6).background(device.color.opacity(0.1)).cornerRadius(8)
                        }
                    }
                    .padding().background(Color.cardBackground).cornerRadius(12)
                    
                    HStack {
                        Image(systemName: "tag.fill").foregroundColor(.gray)
                        TextField("Device Name", text: $customName)
                    }
                    .padding().background(Color.cardBackground).cornerRadius(12)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(rooms, id: \.self) { room in
                                Text(room)
                                    .font(.caption).bold()
                                    .padding(.vertical, 8).padding(.horizontal, 16)
                                    .background(selectedRoom == room ? device.color : Color.cardBackground)
                                    .foregroundColor(selectedRoom == room ? .white : .textPrimary)
                                    .cornerRadius(20)
                                    .onTapGesture { withAnimation { selectedRoom = room } }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                .padding(.horizontal)
                
                if let error = saveError {
                    Text(error).foregroundColor(.red).font(.caption).multilineTextAlignment(.center).padding(.horizontal)
                }
                
                Spacer().frame(height: 10)
                
                // 3. زر الإضافة (يتحرك مع السكرول!)
                Button(action: saveDeviceToFirebase) {
                    Text("Add Device")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: buttonWidth, height: 55)
                        .background(isValidInput ? device.color : Color.gray)
                        .cornerRadius(20)
                        .shadow(color: (isValidInput ? device.color : Color.gray).opacity(0.4), radius: 10, y: 5)
                }
                .disabled(!isValidInput)
                
                // مسافة أمان سفلية كبيرة للكيبورد
                Spacer().frame(height: 300)
            }
        }
    }
    
    // شاشة النجاح
    var successView: some View {
        VStack(spacing: 25) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .scaleEffect(saveSuccess ? 1 : 0.5)
                .animation(.spring(), value: saveSuccess)
            
            Text("Device Added Successfully!")
                .font(.title2).bold()
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 5) {
                Text(customName).font(.headline).foregroundColor(.mainPurple)
                Text("Room: \(selectedRoom)").font(.subheadline).foregroundColor(.textSecondary)
            }
            
            Button("Done") { presentationMode.wrappedValue.dismiss() }
                .font(.headline).foregroundColor(.white).padding()
                .frame(width: 200).background(Color.green).cornerRadius(15).padding(.top, 20)
        }
    }
    
    // MARK: - Logic
    
    var isValidInput: Bool {
        // في الخطوة 2 (الفورم) نتحقق من الحقول
        return !manualMacInput.isEmpty && !customName.isEmpty
    }
    
    func handleNextStep() {
        if currentStep < 2 {
            withAnimation { currentStep += 1 }
        }
    }
    
    func saveDeviceToFirebase() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        isSaving = true
        saveError = nil
        
        let cleanMac = manualMacInput.replacingOccurrences(of: ":", with: "").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanMac.count < 6 {
            saveError = "Invalid Device ID."
            isSaving = false
            return
        }
        
        let db = Firestore.firestore()
        let deviceData: [String: Any] = [
            "macAddress": cleanMac, "name": customName, "room": selectedRoom,
            "type": device.type.rawValue, "ownerEmail": userEmail,
            "online": true, "showOnDashboard": true,
            "addedAt": FieldValue.serverTimestamp(),
            "tankHeight": 200, "maxWaterLevel": 180, "tankVolume": 4.0
        ]
        
        db.collection("devices").document(cleanMac).setData(deviceData, merge: true) { error in
            isSaving = false
            if let error = error { saveError = error.localizedDescription }
            else { withAnimation { saveSuccess = true } }
        }
    }
    
    // MARK: - المكونات الفرعية
    
    // للخطوات 0 و 1 فقط (لأنهم جوا TabView عادي)
    func stepView(title: String, desc: String, icon: String, content: AnyView?) -> some View {
        VStack(spacing: 15) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 35))
                .foregroundColor(device.color.opacity(0.8))
                .frame(width: 70, height: 70)
                .background(device.color.opacity(0.1))
                .clipShape(Circle())
            
            Text(title).font(.headline).bold().foregroundColor(.textPrimary)
            
            Text(.init(desc))
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            if let customContent = content { customContent.padding(.top, 5) }
            Spacer()
        }
        .frame(width: buttonWidth)
    }
    
    var wifiInstructionContent: some View {
        Button(action: {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        }) {
            HStack {
                Text("Open WiFi Settings")
                Image(systemName: "arrow.up.right.circle.fill")
            }
            .font(.headline)
            .foregroundColor(.textPrimary)
            .frame(width: buttonWidth, height: 55)
            .background(Color.cardBackground)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(device.color.opacity(0.5), lineWidth: 1))
        }
    }
}
