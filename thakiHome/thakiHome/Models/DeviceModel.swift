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
    var homeId: String?
    var ownerEmail: String?
    var showOnDashboard: Bool?
    var size: CardSize?
    var macAddress: String?
    
    // بيانات الخزان
    // ملاحظة: val هنا تخزن المسافة (Distance) بالسنتيمتر
    var val: String?
    var tankHeight: Double?
    var maxWaterLevel: Double?
    var tankVolume: Double?

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
    
    // ✅ 1. متغير جديد لحساب النسبة رياضياً
    var calculatedPercentage: Int {
        // التأكد من وجود القيم وتحويل val من String لـ Double
        guard let valString = val,
              let currentDist = Double(valString),
              let height = tankHeight,
              let maxLevel = maxWaterLevel,
              maxLevel > 0 else {
            return 0
        }
        
        // المعادلة: ارتفاع الماء = ارتفاع الخزان - قراءة السنسور
        let waterHeight = height - currentDist
        
        // النسبة = (ارتفاع الماء / أقصى ارتفاع) * 100
        let percentage = (waterHeight / maxLevel) * 100
        
        // ضمان النتيجة بين 0 و 100
        return Swift.max(0, Swift.min(100, Int(percentage)))
    }
    
    // ✅ 2. تعديل safeStatus ليعرض النسبة المحسوبة
    var safeStatus: String {
        if type == "sensor" { return isActive ? "Motion Detected" : "Clear" }
        
        if type == "water_sensor" {
            // إذا الإعدادات موجودة، نعرض النسبة المحسوبة
            if tankHeight != nil && maxWaterLevel != nil {
                return "\(calculatedPercentage)%"
            } else {
                // إذا الإعدادات مش موجودة، نعرض القيمة الخام أو --
                return val != nil ? "\(val!)" : "--"
            }
        }
        
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
