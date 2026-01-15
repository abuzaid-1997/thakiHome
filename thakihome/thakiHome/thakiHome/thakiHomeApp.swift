import SwiftUI
import FirebaseCore // ضروري جداً

@main
struct thakiHomeApp: App {
//    @State private var isLoggedIn = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false

    // 1. إضافة المُنشئ لتهيئة Firebase عند تشغيل التطبيق
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            // 2. التحقق من حالة المستخدم عند فتح التطبيق
            if isLoggedIn {
                ContentView(isLoggedIn: $isLoggedIn)
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
    }
}
