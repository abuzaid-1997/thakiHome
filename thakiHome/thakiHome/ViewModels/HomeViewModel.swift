import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class HomeViewModel: ObservableObject {
    @Published var devices: [DeviceItem] = []
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // معرف البيت الحالي
    private var currentHomeId: String {
        UserDefaults.standard.string(forKey: "currentHomeId") ?? "1"
    }
    
    init() {
        fetchDevices()
    }
    
    // MARK: - 1. Fetch Logic
    func fetchDevices() {
        guard let userEmail = Auth.auth().currentUser?.email else {
            self.devices = []
            return
        }
        
        listener?.remove()
        
        var query: Query
        
        if currentHomeId == "1" {
            // الأدمن: يجلب الأجهزة اللي هو مالكها (بالإيميل)
            // ملاحظة: مع الوقت يفضل نعتمد على homeId حتى للأدمن، لكن حالياً هذا أضمن للكود القديم
            query = db.collection("devices").whereField("ownerEmail", isEqualTo: userEmail)
        } else {
            // العضو: يجلب الأجهزة حسب رقم البيت
            query = db.collection("devices").whereField("homeId", isEqualTo: currentHomeId)
        }
        
        listener = query.addSnapshotListener { [weak self] (querySnapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching devices: \(error)")
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                self.devices = []
                return
            }
            
            self.devices = documents.compactMap { queryDocumentSnapshot -> DeviceItem? in
                return try? queryDocumentSnapshot.data(as: DeviceItem.self)
            }
            .sorted { ($0.safeShowOnDashboard && !$1.safeShowOnDashboard) }
        }
    }
    
    func refreshDevices() {
        fetchDevices()
    }
    
    // MARK: - 2. Add Device (تم التصحيح ✅)
    func addDevice(device: DeviceItem) {
        var newDevice = device // حولناها لـ var عشان نعدل عليها
        let uid = Auth.auth().currentUser?.uid ?? ""
        
        // ✅ إضافة homeId للجهاز الجديد تلقائياً
        if currentHomeId == "1" {
            // إذا كنت في بيتي الرئيسي، رقم البيت هو الـ UID تبعي
            newDevice.homeId = uid
        } else {
            // إذا كنت بضيف جهاز في بيت ثاني
            newDevice.homeId = currentHomeId
        }
        
        do {
            _ = try db.collection("devices").addDocument(from: newDevice)
        } catch {
            print("Error adding device: \(error)")
        }
    }
    
    // MARK: - 3. Device Controls
    func toggleStatus(_ device: DeviceItem) {
        guard let id = device.id else { return }
        
        let newStatus = !device.safeIsActive
        var dataToUpdate: [String: Any] = ["isActive": newStatus]
        
        if device.type != "water_sensor" {
            dataToUpdate["status"] = newStatus ? "On" : "Off"
        }
        
        db.collection("devices").document(id).updateData(dataToUpdate)
    }
    
    func setDeviceSize(_ device: DeviceItem, size: CardSize) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index].size = size
        }
        guard let id = device.id else { return }
        db.collection("devices").document(id).updateData(["size": size.rawValue])
    }
    
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
    
    func deleteDevicePermanently(_ device: DeviceItem) {
        guard let id = device.id else { return }
        db.collection("devices").document(id).updateData(["resetCommand": true])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.db.collection("devices").document(id).delete()
            if let index = self.devices.firstIndex(where: { $0.id == id }) {
                self.devices.remove(at: index)
            }
        }
    }
    
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
