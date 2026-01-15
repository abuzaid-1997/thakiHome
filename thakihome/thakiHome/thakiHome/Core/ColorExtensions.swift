import SwiftUI

extension Color {
    // MARK: - 1. Theme Colors (ألوان الثيم الذكية)
    
    // لون البراند (لافندر بالليل، بنفسجي غامق بالنهار)
    static var mainPurple: Color {
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 1.0) : UIColor(red: 0.27, green: 0.0, blue: 0.45, alpha: 1.0) })
    }
    
    // خلفية التطبيق (أسود بالليل، رمادي فاتح بالنهار)
    static var themeBackground: Color {
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor.black : UIColor.systemGroupedBackground })
    }
    
    // خلفية الكروت (رمادي غامق بالليل، أبيض بالنهار)
    static var cardBackground: Color {
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) : UIColor.white })
    }
    
    // النصوص الأساسية
    static var textPrimary: Color {
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor.white : UIColor.black })
    }
    
    // النصوص الفرعية
    static var textSecondary: Color {
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor.lightGray : UIColor.gray })
    }
}
