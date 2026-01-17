import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// موديل البيت
struct HomeModel: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
}

struct HomeHeaderView: View {
    // القائمة المنسدلة
    @State private var myHomes: [HomeModel] = []
    
    // ✅ متغير جديد لاسم البيت الظاهر في العنوان (منفصل عن القائمة)
    @State private var displayedHomeName: String = "My Home"
    
    @AppStorage("currentHomeId") private var currentHomeId: String = "1"
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome Back,")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.leading, 2)
                
                // القائمة المنسدلة
                Menu {
                    // الخيار الافتراضي
                    Button(action: { switchToHome(id: "1", name: "My Home") }) {
                        HStack {
                            Text("My Home")
                            if currentHomeId == "1" { Image(systemName: "checkmark") }
                        }
                    }
                    
                    Divider()
                    
                    // البيوت المنضم إليها
                    ForEach(myHomes) { home in
                        Button(action: { switchToHome(id: home.id, name: home.name) }) {
                            HStack {
                                Text(home.name)
                                if currentHomeId == home.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                    
                    Divider()
                    
                    NavigationLink(destination: FamilyManagementView()) {
                        Label("Manage Homes", systemImage: "gearshape")
                    }
                    
                } label: {
                    HStack(spacing: 8) {
                        // ✅ نستخدم المتغير الجديد هنا
                        Text(displayedHomeName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.mainPurple)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.mainPurple.opacity(0.6))
                            .padding(.top, 4)
                    }
                }
            }
            
            Spacer()
            
            Button(action: { }) {
                ZStack {
                    Circle()
                        .fill(Color.cardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .frame(width: 45, height: 45)
                    
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.mainPurple)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 10)
        .onAppear {
                    fetchUserHomesList()
                    fetchCurrentHomeName()
                }
                // ✅ الصيغة الجديدة المتوافقة مع iOS 17
                .onChange(of: currentHomeId) {
                    fetchCurrentHomeName()
                }
            }
    
    // دالة مساعدة للتبديل
    func switchToHome(id: String, name: String) {
        withAnimation {
            currentHomeId = id
            // تحديث مبدئي سريع
            displayedHomeName = name
        }
    }
    
    // MARK: - Firebase Logic
    
    // 1. جلب الاسم الحقيقي للبيت الحالي (Fix for Loading Issue)
    func fetchCurrentHomeName() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // إذا كان البيت هو "1"، نحاول جلب اسمه من وثيقة المستخدم الشخصية
        if currentHomeId == "1" {
             Firestore.firestore().collection("households").document(uid).getDocument { doc, _ in
                 if let data = doc?.data(), let name = data["homeName"] as? String {
                     self.displayedHomeName = name
                 } else {
                     self.displayedHomeName = "My Home"
                 }
             }
        } else {
            // إذا كان بيت عائلة، نجلبه من households مباشرة (أضمن طريقة)
            Firestore.firestore().collection("households").document(currentHomeId).addSnapshotListener { doc, error in
                if let data = doc?.data(), let name = data["homeName"] as? String {
                    self.displayedHomeName = name
                }
            }
        }
    }
    
    // 2. جلب القائمة المنسدلة
    // 2. جلب القائمة المنسدلة (نسخة ذكية تجلب الأسماء الحقيقية)
        func fetchUserHomesList() {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            Firestore.firestore().collection("users").document(uid)
                .addSnapshotListener { document, error in
                    guard let document = document, document.exists,
                          let data = document.data() else { return }
                    
                    if let homesArray = data["joinedHomes"] as? [[String: String]] {
                        
                        var tempHomes: [HomeModel] = []
                        let group = DispatchGroup() // مجموعة لمزامنة العمليات
                        
                        for dict in homesArray {
                            guard let id = dict["homeId"],
                                  let role = dict["role"] else { continue }
                            
                            // تخطي البيت المحلي رقم 1
                            if id == "1" { continue }
                            
                            group.enter()
                            // 🔍 الذهاب للمصدر الأصلي (Households) لجلب الاسم الحقيقي
                            Firestore.firestore().collection("households").document(id).getDocument { doc, _ in
                                // إذا وجدنا اسم حقيقي نستخدمه، وإلا نستخدم الاسم المخزن مؤقتاً
                                let realName = doc?.data()?["homeName"] as? String ?? dict["homeName"] ?? "Unknown"
                                
                                let home = HomeModel(id: id, name: realName, role: role)
                                tempHomes.append(home)
                                group.leave()
                            }
                        }
                        
                        // عند انتهاء جلب جميع الأسماء، نحدث القائمة
                        group.notify(queue: .main) {
                            self.myHomes = tempHomes
                        }
                    }
                }
        }
}
