//
//  BluetoothManager.swift
//  thakiHome
//
//  Created by Mohamad Abuzaid on 14/01/2026.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isScanning = false
    @Published var foundPeripheral: CBPeripheral?
    @Published var connectionStatus = "Searching..."
    @Published var isConnected = false
    
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    
    // ⚠️ يجب أن تطابق هذه القيم كود الأردوينو تماماً
    let SERVICE_UUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    let CHAR_SSID_UUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    let CHAR_PASS_UUID = CBUUID(string: "8897c83f-1d84-4874-a64d-522778747d95")
    let CHAR_SAVE_UUID = CBUUID(string: "93c04294-22b6-4556-91f8-06775086cb4f")
    
    private var ssidChar: CBCharacteristic?
    private var passChar: CBCharacteristic?
    private var saveChar: CBCharacteristic?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        connectionStatus = "Scanning for Thaki Light..."
        // نبحث فقط عن الأجهزة التي تبث الخدمة الخاصة بنا
        centralManager.scanForPeripherals(withServices: [SERVICE_UUID], options: nil)
    }
    
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }
    
    func connectToDevice() {
        guard let p = foundPeripheral else { return }
        centralManager.stopScan()
        connectionStatus = "Connecting..."
        centralManager.connect(p, options: nil)
    }
    
    func sendCredentials(ssid: String, pass: String) {
        guard let p = targetPeripheral, let sChar = ssidChar, let pChar = passChar, let svChar = saveChar else {
            connectionStatus = "Error: Channels not ready"
            return
        }
        
        // 1. إرسال اسم الشبكة
        if let data = ssid.data(using: .utf8) {
            p.writeValue(data, for: sChar, type: .withResponse)
        }
        
        // 2. إرسال الباسوورد
        // ملاحظة: نرسل الباسوورد وننتظر قليلاً قبل الحفظ
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let data = pass.data(using: .utf8) {
                p.writeValue(data, for: pChar, type: .withResponse)
            }
        }
        
        // 3. إرسال أمر الحفظ (رقم 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let data = "1".data(using: .utf8) {
                p.writeValue(data, for: svChar, type: .withResponse)
                self.connectionStatus = "Sent! Device is connecting..."
            }
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // startScanning()  <-- ⚠️ احذف هذا السطر أو اعمله تعليق (Comment)
            connectionStatus = "Ready to Scan"
        } else {
            connectionStatus = "Bluetooth is Off"
            isScanning = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // وجدنا الجهاز!
        foundPeripheral = peripheral
        targetPeripheral = peripheral
        connectionStatus = "Thaki Light Found!"
        stopScanning() // نتوقف عن البحث
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectionStatus = "Connected! Preparing..."
        peripheral.delegate = self
        peripheral.discoverServices([SERVICE_UUID])
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([CHAR_SSID_UUID, CHAR_PASS_UUID, CHAR_SAVE_UUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for char in characteristics {
            if char.uuid == CHAR_SSID_UUID { ssidChar = char }
            if char.uuid == CHAR_PASS_UUID { passChar = char }
            if char.uuid == CHAR_SAVE_UUID { saveChar = char }
        }
        
        if ssidChar != nil && passChar != nil && saveChar != nil {
            DispatchQueue.main.async {
                self.connectionStatus = "Ready to Setup"
            }
        }
    }
}
