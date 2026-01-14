import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class HomeViewModel: ObservableObject {
    @Published var devices: [DeviceItem] = []
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    init() {
        // ✅ تفعيل الاتصال الحقيقي فوراً عند التشغيل
        fetchDevices()
    }
    
    // 1. الاستماع المباشر للتغييرات من الفايربيس
    func fetchDevices() {
        guard let userEmail = Auth.auth().currentUser?.email else {
            print("⚠️ No logged in user")
            self.devices = []
            return
        }
        
        listener?.remove()
        
        listener = db.collection("devices")
            .whereField("ownerEmail", isEqualTo: userEmail)
            .addSnapshotListener { (querySnapshot, error) in
                guard let documents = querySnapshot?.documents else {
                    print("No documents found")
                    return
                }
                
                self.devices = documents.compactMap { queryDocumentSnapshot -> DeviceItem? in
                    return try? queryDocumentSnapshot.data(as: DeviceItem.self)
                }
                .sorted { ($0.safeShowOnDashboard && !$1.safeShowOnDashboard) }
            }
    }
    
    // 2. إضافة جهاز جديد
    func addDevice(device: DeviceItem) {
        do {
            let _ = try db.collection("devices").addDocument(from: device)
        } catch {
            print("Error adding device: \(error)")
        }
    }
    
    // 3. تشغيل/إطفاء
    func toggleStatus(_ device: DeviceItem) {
        guard let id = device.id else { return }
        
        let newStatus = !device.safeIsActive
        var dataToUpdate: [String: Any] = ["isActive": newStatus]
        
        // للأجهزة العادية نحدث النص، للخزان لا نلمسه
        if device.type != "water_sensor" {
            dataToUpdate["status"] = newStatus ? "On" : "Off"
        }
        
        db.collection("devices").document(id).updateData(dataToUpdate)
    }
    
    // 4. حفظ حجم الكرت المخصص
    func setDeviceSize(_ device: DeviceItem, size: CardSize) {
        // تحديث محلي سريع
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index].size = size
        }
        // تحديث الفايربيس
        guard let id = device.id else { return }
        db.collection("devices").document(id).updateData(["size": size.rawValue])
    }
    
    // دالة لتغيير الحجم عند السحب
    func resizeDevice(_ device: DeviceItem) {
        let currentSize = device.safeSize
        let newSize: CardSize
        switch currentSize {
        case .small: newSize = .wide
        case .wide: newSize = .tall
        case .tall: newSize = .big
        case .big: newSize = .small
        }
        setDeviceSize(device, size: newSize)
    }
    
    // 5. التحكم في الداشبورد
    func updateDashboardStatus(device: DeviceItem, show: Bool) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index].showOnDashboard = show
        }
        guard let id = device.id else { return }
        db.collection("devices").document(id).updateData(["showOnDashboard": show])
    }
    
    func removeFromDashboard(_ device: DeviceItem) {
        updateDashboardStatus(device: device, show: false)
    }
    
    // 6. الحذف النهائي
    func deleteDevicePermanently(_ device: DeviceItem) {
        guard let id = device.id else { return }
        
        // إرسال أمر تصفير للجهاز قبل الحذف (اختياري)
        db.collection("devices").document(id).updateData(["resetCommand": true])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.db.collection("devices").document(id).delete()
            if let index = self.devices.firstIndex(where: { $0.id == id }) {
                self.devices.remove(at: index)
            }
        }
    }
    
    // 7. تحديث الاسم والغرفة
    func updateDeviceName(device: DeviceItem, newName: String) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) { devices[index].name = newName }
        guard let id = device.id else { return }
        db.collection("devices").document(id).updateData(["name": newName])
    }
    
    func updateDeviceRoom(device: DeviceItem, newRoom: String) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) { devices[index].room = newRoom }
        guard let id = device.id else { return }
        db.collection("devices").document(id).updateData(["room": newRoom])
    }
    
    // 8. ✅ تحديث إعدادات الخزان
    func updateTankConfig(device: DeviceItem, height: Double, maxLevel: Double, volume: Double) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index].tankHeight = height
            devices[index].maxWaterLevel = maxLevel
            devices[index].tankVolume = volume
        }
        guard let id = device.id else { return }
        db.collection("devices").document(id).updateData([
            "tankHeight": height,
            "maxWaterLevel": maxLevel,
            "tankVolume": volume
        ])
    }
    
    var availableRooms: [String] {
        let rooms = devices.compactMap { $0.room }.filter { !$0.isEmpty && $0 != "Unassigned" }
        return Array(Set(rooms)).sorted()
    }
}
