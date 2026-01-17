import SwiftUI

struct DeviceDetailsView: View {
    @ObservedObject var viewModel: HomeViewModel
    let initialDevice: DeviceItem
    
    @Environment(\.presentationMode) var presentationMode
    
    // ✅ 1. مفتاح الأمان: معرفة هل المستخدم هو الأدمن؟
    @AppStorage("currentHomeId") var currentHomeId: String = "1"
    
    // متغيرات التعديل
    @State private var editingNameString: String = ""
    @State private var editingRoomString: String = ""
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var isAddingNewRoom = false
    
    // متغيرات إعدادات الخزان
    @State private var tankHeightInput: String = ""
    @State private var maxLevelInput: String = ""
    @State private var tankVolumeInput: String = ""
    
    var liveDevice: DeviceItem {
        return viewModel.devices.first(where: { $0.id == initialDevice.id }) ?? initialDevice
    }
    
    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // مقبض الـ Sheet
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 6)
                        .padding(.top, 20)
                    
                    // الأيقونة الكبيرة
                    ZStack {
                        Circle()
                            .fill(liveDevice.safeIsActive ? Color.mainPurple.opacity(0.15) : Color.cardBackground)
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        
                        Image(systemName: liveDevice.safeIcon)
                            .font(.system(size: 50))
                            .foregroundColor(liveDevice.safeIsActive ? .mainPurple : .gray)
                    }
                    .padding(.top, 10)
                    
                    // قسم الاسم والحالة
                    VStack(spacing: 5) {
                        if isEditing {
                            // وضع التعديل
                            VStack(spacing: 15) {
                                TextField("Device Name", text: $editingNameString)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                                
                                // قائمة الغرف
                                if isAddingNewRoom {
                                    HStack {
                                        TextField("New Room Name", text: $editingRoomString)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                        Button(action: { isAddingNewRoom = false; editingRoomString = liveDevice.safeRoom }) {
                                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                        }
                                    }.padding(.horizontal)
                                } else {
                                    Menu {
                                        ForEach(viewModel.availableRooms, id: \.self) { room in
                                            Button(room) { editingRoomString = room }
                                        }
                                        Divider()
                                        Button(action: { editingRoomString = ""; isAddingNewRoom = true }) {
                                            Label("Add New Room", systemImage: "plus")
                                        }
                                    } label: {
                                        HStack {
                                            Text(editingRoomString.isEmpty ? "Select Room" : editingRoomString)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundColor(.gray)
                                        }
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                    }.padding(.horizontal)
                                }
                                
                                // إعدادات الخزان (تظهر فقط في وضع التعديل للخزان)
                                if liveDevice.type == "water_sensor" {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Tank Configuration").font(.headline).padding(.top)
                                        
                                        HStack {
                                            Text("Sensor Height (cm):")
                                            TextField("200", text: $tankHeightInput).keyboardType(.decimalPad).textFieldStyle(RoundedBorderTextFieldStyle())
                                        }
                                        HStack {
                                            Text("Max Water Level (cm):")
                                            TextField("180", text: $maxLevelInput).keyboardType(.decimalPad).textFieldStyle(RoundedBorderTextFieldStyle())
                                        }
                                        HStack {
                                            Text("Total Volume (m³):")
                                            TextField("4.0", text: $tankVolumeInput).keyboardType(.decimalPad).textFieldStyle(RoundedBorderTextFieldStyle())
                                        }
                                    }
                                    .padding()
                                    .background(Color.cardBackground)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                                
                                Button("Save Changes") {
                                    saveChanges()
                                }
                                .bold()
                                .foregroundColor(.mainPurple)
                                .padding(.top, 5)
                            }
                        } else {
                            // وضع العرض
                            HStack {
                                Text(liveDevice.name).font(.title2).bold().foregroundColor(.textPrimary)
                                
                                // ✅ تحسين إضافي: إخفاء قلم التعديل عن الأعضاء أيضاً (اختياري، لكن يفضل)
                                if currentHomeId == "1" {
                                    Button(action: startEditing) {
                                        Image(systemName: "pencil.circle.fill").font(.title3).foregroundColor(.gray)
                                    }
                                }
                            }
                            Text(liveDevice.safeStatus).font(.subheadline).foregroundColor(.textSecondary)
                        }
                    }
                    
                    Divider().padding(.horizontal)
                    
                    // أزرار التحكم
                    VStack(spacing: 20) {
                        
                        // زر التشغيل
                        if liveDevice.type != "water_sensor" {
                            Button(action: { viewModel.toggleStatus(liveDevice) }) {
                                HStack {
                                    Image(systemName: "power")
                                    Text(liveDevice.safeIsActive ? "Turn Off" : "Turn On")
                                }
                                .bold()
                                .frame(maxWidth: .infinity).padding()
                                .background(liveDevice.safeIsActive ? Color.mainPurple : Color.cardBackground)
                                .foregroundColor(liveDevice.safeIsActive ? .white : .textPrimary)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                            }
                        } else {
                            HStack(spacing: 20) {
                                TankInfoBadge(title: "Capacity", val: "\(liveDevice.tankVolume ?? 0) m³")
                                TankInfoBadge(title: "Height", val: "\(liveDevice.tankHeight ?? 0) cm")
                            }
                        }
                        
                        // خيار الداشبورد
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Show on Dashboard").font(.headline).foregroundColor(.textPrimary)
                                Text("Visible on Home screen").font(.caption).foregroundColor(.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { liveDevice.safeShowOnDashboard },
                                set: { viewModel.updateDashboardStatus(device: liveDevice, show: $0) }
                            )).labelsHidden().toggleStyle(SwitchToggleStyle(tint: .mainPurple))
                        }
                        .padding().background(Color.cardBackground).cornerRadius(12).shadow(color: .black.opacity(0.05), radius: 5)
                        
                        // معلومات تقنية
                        VStack(spacing: 0) {
                            HStack {
                                Text("Room").foregroundColor(.textPrimary)
                                Spacer()
                                Text(liveDevice.safeRoom).foregroundColor(.textSecondary)
                            }.padding()
                            Divider().padding(.horizontal)
                            HStack {
                                Text("MAC Address").foregroundColor(.textPrimary)
                                Spacer()
                                Text(liveDevice.safeMac).font(.system(.caption, design: .monospaced)).foregroundColor(.textSecondary)
                            }.padding()
                        }
                        .background(Color.cardBackground).cornerRadius(12).shadow(color: .black.opacity(0.05), radius: 5)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // ✅✅✅ هنا التعديل الأمني: زر الحذف للأدمن فقط
                    if currentHomeId == "1" {
                        Button(action: { showDeleteConfirmation = true }) {
                            Text("Delete Device").bold().foregroundColor(.red).padding()
                                .frame(maxWidth: .infinity).background(Color.red.opacity(0.1)).cornerRadius(12)
                        }
                        .padding(.horizontal).padding(.bottom, 20)
                        .alert(isPresented: $showDeleteConfirmation) {
                            Alert(
                                title: Text("Delete Device?"),
                                message: Text("This will permanently remove the device."),
                                primaryButton: .destructive(Text("Delete")) {
                                    viewModel.deleteDevicePermanently(liveDevice)
                                    presentationMode.wrappedValue.dismiss()
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }
                    // ✅✅✅ نهاية التعديل
                }
            }
        }
    }
    
    // دوال مساعدة
    func startEditing() {
        editingNameString = liveDevice.name
        editingRoomString = liveDevice.safeRoom
        if let h = liveDevice.tankHeight { tankHeightInput = String(h) }
        if let m = liveDevice.maxWaterLevel { maxLevelInput = String(m) }
        if let v = liveDevice.tankVolume { tankVolumeInput = String(v) }
        
        isEditing = true
        isAddingNewRoom = false
    }
    
    func saveChanges() {
        if !editingNameString.isEmpty {
            viewModel.updateDeviceName(device: liveDevice, newName: editingNameString)
        }
        viewModel.updateDeviceRoom(device: liveDevice, newRoom: editingRoomString)
        
        if liveDevice.type == "water_sensor" {
            let h = Double(tankHeightInput) ?? 0.0
            let m = Double(maxLevelInput) ?? 0.0
            let v = Double(tankVolumeInput) ?? 0.0
            viewModel.updateTankConfig(device: liveDevice, height: h, maxLevel: m, volume: v)
        }
        
        isEditing = false
        isAddingNewRoom = false
    }
}

struct TankInfoBadge: View {
    let title: String
    let val: String
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.gray)
            Text(val).font(.headline).bold().foregroundColor(.mainPurple)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}
