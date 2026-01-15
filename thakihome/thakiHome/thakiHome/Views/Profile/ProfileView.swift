import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import MessageUI // ضروري لفتح الإيميل

struct ProfileView: View {
    @Binding var isLoggedIn: Bool
    
    // متغيرات بيانات المستخدم
    @State private var userName = "Loading..."
    @State private var userEmail = ""
    @State private var userPhone = ""
    @State private var userCountry = ""
    @State private var userCity = ""
    
    // للتحكم في فتح الصفحات
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.themeBackground.ignoresSafeArea()
                
                List {
                    // 1. قسم المستخدم (قابل للنقر للتعديل)
                    Section {
                        Button(action: { showEditProfile = true }) {
                            HStack(spacing: 15) {
                                ZStack {
                                    Circle().fill(Color.mainPurple.opacity(0.1)).frame(width: 70, height: 70)
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable().frame(width: 70, height: 70)
                                        .foregroundColor(.mainPurple)
                                        .background(Circle().fill(Color.white))
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(userName).font(.title3).bold().foregroundColor(.textPrimary)
                                    Text(userEmail).font(.subheadline).foregroundColor(.textSecondary)
                                    Text("Edit Profile").font(.caption).foregroundColor(.mainPurple)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.gray)
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    .listRowBackground(Color.cardBackground)
                    
                    // 2. الإعدادات والأمان
                    Section(header: Text("Settings").foregroundColor(.textSecondary)) {
                        
                        // زر الأمان (تغيير الباسوورد)
                        NavigationLink(destination: SecurityView()) {
                            Label { Text("Security & Password").foregroundColor(.textPrimary) }
                            icon: { Image(systemName: "lock.shield.fill").foregroundColor(.mainPurple) }
                        }
                        
                        // معلومات إضافية (عرض فقط)
                        if !userCountry.isEmpty {
                            HStack {
                                Label { Text("Location").foregroundColor(.textPrimary) }
                                icon: { Image(systemName: "mappin.circle.fill").foregroundColor(.mainPurple) }
                                Spacer()
                                Text("\(userCity), \(userCountry)").foregroundColor(.textSecondary).font(.caption)
                            }
                        }
                    }
                    .listRowBackground(Color.cardBackground)
                    
                    // 3. الدعم والمساعدة
                    Section(header: Text("Support").foregroundColor(.textSecondary)) {
                        // صفحة المساعدة (بسيطة حالياً)
                        NavigationLink(destination: HelpView()) {
                            Label { Text("Help Center").foregroundColor(.textPrimary) }
                            icon: { Image(systemName: "questionmark.circle.fill").foregroundColor(.orange) }
                        }
                        
                        // زر اتصل بنا (يفتح الإيميل)
                        Button(action: openEmailSupport) {
                            HStack {
                                Label { Text("Contact Us").foregroundColor(.textPrimary) }
                                icon: { Image(systemName: "envelope.fill").foregroundColor(.blue) }
                            }
                        }
                    }
                    .listRowBackground(Color.cardBackground)
                    
                    // 4. تسجيل الخروج
                    Section {
                        Button(action: {
                            try? Auth.auth().signOut()
                            withAnimation { isLoggedIn = false }
                        }) {
                            HStack {
                                Spacer()
                                Text("Sign Out").fontWeight(.bold).foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(Color.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Me")
            // نفتح صفحة التعديل كـ Sheet
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(fullName: userName, phone: userPhone, country: userCountry, city: userCity)
            }
            .onAppear { fetchUserData() }
        }
    }
    
    // جلب البيانات
    func fetchUserData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).addSnapshotListener { document, error in
            if let document = document, document.exists {
                let data = document.data()
                self.userName = data?["full_name"] as? String ?? "User"
                self.userEmail = data?["email"] as? String ?? Auth.auth().currentUser?.email ?? ""
                self.userPhone = data?["phone"] as? String ?? ""
                self.userCountry = data?["country"] as? String ?? ""
                self.userCity = data?["city"] as? String ?? ""
            }
        }
    }
    
    // فتح تطبيق الإيميل
    func openEmailSupport() {
        let email = "support@thakihome.com" // استبدله بإيميلك الحقيقي
        if let url = URL(string: "mailto:\(email)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// صفحة مساعدة بسيطة مدمجة
struct HelpView: View {
    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("FAQ").font(.largeTitle).bold().foregroundColor(.mainPurple)
                    
                    faqItem(q: "How to add a device?", a: "Go to the 'Add' tab, make sure your device is in pairing mode, and follow the instructions.")
                    faqItem(q: "How to reset my device?", a: "Hold the reset button on your hardware for 5 seconds until the LED blinks.")
                    faqItem(q: "How to invite family?", a: "Family sharing is coming soon in the next update!")
                    
                    Spacer()
                }.padding()
            }
        }
        .navigationTitle("Help Center")
    }
    
    func faqItem(q: String, a: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(q).font(.headline).foregroundColor(.textPrimary)
            Text(a).font(.body).foregroundColor(.textSecondary)
            Divider().padding(.top, 10)
        }
    }
}
