//
//  DeviceModel.swift
//
import SwiftUI
import FirebaseFirestore

enum CardSize: String, Codable {
    case small, wide, tall, big
}

struct DeviceItem: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var type: String
    var room: String
    var status: String
    var isActive: Bool
    
    var ownerEmail: String?
    var showOnDashboard: Bool?
    var size: CardSize?
    var macAddress: String?
    
    // ✅ بيانات الخزان (الجديدة)
    var val: String?                // النسبة المئوية الحالية
    var tankHeight: Double?         // ارتفاع الخزان الكلي (أو الحساس عن القاع)
    var maxWaterLevel: Double?      // أقصى ارتفاع للمياه
    var tankVolume: Double?         // سعة الخزان الكلية (بالمتر المكعب أو الليتر)

    // قيم افتراضية
    var safeRoom: String { return room.isEmpty ? "Unassigned" : room }
    var safeShowOnDashboard: Bool { return showOnDashboard ?? true }
    var safeMac: String { return macAddress ?? "00:00:00:00:00:00" }

    var safeIcon: String {
        switch type {
        case "light": return isActive ? "lightbulb.fill" : "lightbulb"
        case "fan": return "fanblades.fill"
        case "ac": return "snowflake"
        case "tv": return "tv.fill"
        case "water_sensor": return "drop.fill"
        case "sensor": return "sensor.tag.radiowaves.forward.fill"
        default: return "powerplug"
        }
    }
    
    var safeStatus: String {
        if type == "sensor" { return isActive ? "Motion Detected" : "Clear" }
        // عرض النسبة
        if type == "water_sensor" { return val != nil ? "\(val!)%" : "--" }
        return isActive ? "On" : "Off"
    }
    
    var safeIsActive: Bool { return isActive }
    
    var safeSize: CardSize {
        if let storedSize = size { return storedSize }
        switch type {
        case "light", "water_sensor": return .small
        case "fan", "ac": return .wide
        case "tv": return .tall
        default: return .small
        }
    }
}
