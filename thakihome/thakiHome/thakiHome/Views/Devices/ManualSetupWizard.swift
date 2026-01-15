//
//  ManualSetupWizard.swift
//  thakiHome
//
//  Created by Mohamad Abuzaid on 14/01/2026.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Enums
// تعريف أنواع الأجهزة للإضافة
// MARK: - Enums
// تعريف أنواع الأجهزة للإضافة
enum DeviceTypeForAdd: String, Identifiable, CaseIterable {
    case light
    case fan
    case ac
    case sensor
    case waterSensor = "water_sensor" // حساس الخزان
    case airPurifier = "air_purifier" // منقي الهواء
    case dehumidifier                 // ساحب الرطوبة
    case gasSensor = "gas_sensor"     // حساس الغاز
    case smartSwitch = "switch"       // السويتش الذكي
    case curtain                      // الستارة
    case lock                         // القفل
    case irrigation                   // نظام الري
    
    var id: String { self.rawValue }
}
// MARK: - Manual Setup Wizard View
struct ManualSetupWizard: View {
    @Environment(\.presentationMode) var presentationMode
    @State var selectedDeviceType: DeviceTypeForAdd
    
    // Initializer عشان نقدر نمرر nil إذا بدنا
    init(selectedDeviceType: DeviceTypeForAdd?) {
        _selectedDeviceType = State(initialValue: selectedDeviceType ?? .light)
    }
    
    // Steps Control
    @State private var step = 1
    @State private var manualMacInput = ""
    @State private var customName = ""
    @State private var selectedRoom = "Living Room"
    @State private var addToDashboard = true
    @State private var isLinking = false
    @State private var linkError: String?
    @State private var success = false

    let rooms = ["Living Room", "Bedroom", "Kitchen", "Roof", "Garden", "Bathroom"]

    var body: some View {
        VStack(spacing: 20) {
            // Header Steps Indicator
            HStack {
                Circle().fill(step >= 1 ? Color.mainPurple : Color.gray.opacity(0.3)).frame(width: 10)
                Rectangle().fill(step >= 2 ? Color.mainPurple : Color.gray.opacity(0.3)).frame(height: 2)
                Circle().fill(step >= 2 ? Color.mainPurple : Color.gray.opacity(0.3)).frame(width: 10)
                Rectangle().fill(step >= 3 ? Color.mainPurple : Color.gray.opacity(0.3)).frame(height: 2)
                Circle().fill(step >= 3 ? Color.mainPurple : Color.gray.opacity(0.3)).frame(width: 10)
            }
            .padding(.top, 20).padding(.horizontal, 50)
            
            // Switch Views based on Step
            if step == 1 { stepOneView }
            else if step == 2 { stepTwoView }
            else if step == 3 {
                if success { successView } else { stepThreeConfigView }
            }
            
            Spacer()
            
            // Footer Buttons
            if !success {
                HStack {
                    if step > 1 {
                        Button("Back") { withAnimation { step -= 1 } }.foregroundColor(.gray)
                    }
                    Spacer()
                    if step == 3 {
                        Button(action: finalizeSetup) {
                            Text(isLinking ? "Saving..." : "Finish").bold()
                                .padding(.vertical, 10).padding(.horizontal, 30)
                                .background(Color.mainPurple).foregroundColor(.white).cornerRadius(10)
                        }.disabled(isLinking || customName.isEmpty)
                    }
                }.padding()
            } else {
                Button("Done") { presentationMode.wrappedValue.dismiss() }
                    .buttonStyle(.borderedProminent).tint(.green).padding()
            }
        }
    }
    
    // --- Step 1: WiFi Instructions ---
    var stepOneView: some View {
        ScrollView {
            VStack(spacing: 25) {
                Image(systemName: "wifi.square.fill").font(.system(size: 70)).foregroundColor(.mainPurple)
                Text("Connect Device").font(.title2).bold()
                VStack(alignment: .leading, spacing: 10) {
                    Text("1. Connect to 'ThakiHome' WiFi.").font(.subheadline)
                    Text("2. Copy the Device ID shown.").font(.subheadline).bold()
                }.padding().background(Color.gray.opacity(0.05)).cornerRadius(12)
                
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }) {
                    HStack { Text("Open WiFi Settings"); Spacer(); Image(systemName: "arrow.up.right") }
                        .padding().background(Color.mainPurple.opacity(0.1)).cornerRadius(10)
                }.padding(.horizontal)
                
                Button("Next: Enter ID") { withAnimation { step = 2 } }
                    .padding().frame(maxWidth: .infinity).background(Color.mainPurple).foregroundColor(.white).cornerRadius(12).padding(.top)
            }.padding()
        }
    }
    
    // --- Step 2: Enter ID ---
    var stepTwoView: some View {
        VStack(spacing: 25) {
            Text("Enter Device ID").font(.title2).bold()
            HStack {
                Image(systemName: "barcode.viewfinder").foregroundColor(.gray)
                TextField("Ex: 10:00:3B:...", text: $manualMacInput)
                if UIPasteboard.general.hasStrings {
                    Button("Paste") { if let string = UIPasteboard.general.string { manualMacInput = string } }
                        .font(.caption).bold().foregroundColor(.mainPurple)
                }
            }.padding().background(Color.gray.opacity(0.1)).cornerRadius(12).padding(.horizontal)
            
            Button("Next: Configure") {
                let clean = manualMacInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    self.manualMacInput = clean
                    if customName.isEmpty { customName = "My Device" }
                    withAnimation { step = 3 }
                }
            }.disabled(manualMacInput.isEmpty)
                .padding().frame(maxWidth: .infinity)
                .background(manualMacInput.isEmpty ? Color.gray : Color.mainPurple)
                .foregroundColor(.white).cornerRadius(12).padding(.horizontal)
        }
    }
    
    // --- Step 3: Config ---
    var stepThreeConfigView: some View {
        ScrollView {
            VStack(spacing: 25) {
                Text("Customize Device").font(.title2).bold()
                
                VStack(alignment: .leading) {
                    Text("Device Type").font(.caption).foregroundColor(.gray)
                    Picker("Type", selection: $selectedDeviceType) {
                        ForEach(DeviceTypeForAdd.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }.pickerStyle(SegmentedPickerStyle())
                }

                VStack(alignment: .leading) {
                    Text("Device Name").font(.caption).foregroundColor(.gray)
                    TextField("Ex: Roof Tank", text: $customName)
                        .padding().background(Color.gray.opacity(0.1)).cornerRadius(10)
                }
                
                VStack(alignment: .leading) {
                    Text("Select Room").font(.caption).foregroundColor(.gray)
                    Menu {
                        ForEach(rooms, id: \.self) { room in Button(room) { selectedRoom = room } }
                    } label: {
                        HStack {
                            Text(selectedRoom).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down").foregroundColor(.gray)
                        }.padding().background(Color.gray.opacity(0.1)).cornerRadius(10)
                    }
                }
                
                Toggle(isOn: $addToDashboard) {
                    Text("Add to Dashboard").bold()
                }.padding().background(Color.gray.opacity(0.05)).cornerRadius(10)
                
                if let error = linkError { Text(error).foregroundColor(.red).font(.caption) }
                if isLinking { ProgressView().padding() }
            }.padding()
        }
    }
    
    // --- Success View ---
    var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 80)).foregroundColor(.green)
            Text("All Set!").font(.title).bold()
        }
    }

    // --- Logic ---
    func finalizeSetup() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        isLinking = true
        let db = Firestore.firestore()
        
        let cleanMac = manualMacInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let docRef = db.collection("devices").document(cleanMac)
        
        docRef.getDocument { (document, error) in
            let updateData: [String: Any] = [
                "ownerEmail": userEmail,
                "name": customName,
                "room": selectedRoom,
                "type": selectedDeviceType.rawValue,
                "showOnDashboard": addToDashboard,
                "online": true,
                "macAddress": cleanMac,
                "tankHeight": 200, "maxWaterLevel": 180, "tankVolume": 4.0
            ]
            
            if let document = document, document.exists {
                docRef.setData(updateData, merge: true) { error in handleResult(error) }
            } else {
                var newData = updateData
                newData["addedAt"] = FieldValue.serverTimestamp()
                docRef.setData(newData, merge: true) { error in handleResult(error) }
            }
        }
    }
    
    func handleResult(_ error: Error?) {
        isLinking = false
        if let error = error { linkError = error.localizedDescription } else { withAnimation { success = true } }
    }
}
