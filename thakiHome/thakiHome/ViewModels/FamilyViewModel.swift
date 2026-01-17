import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class FamilyViewModel: ObservableObject {
    @Published var members: [FamilyMember] = []
    @Published var incomingInvites: [IncomingInvite] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentHomeName: String = "Loading..."
    private var db = Firestore.firestore()
    private var currentUserEmail = Auth.auth().currentUser?.email ?? ""
    
    // البيت الحالي
    @AppStorage("currentHomeId") var currentHomeId: String = "1"

    init() {
        fetchMembers()
        fetchIncomingInvites()
    }
    
    // MARK: - 1. جلب أعضاء البيت الحالي (مصححة لاسم البيت)
        func fetchMembers() {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            // إذا البيت رقم 1، نستخدم الـ UID. غير ذلك نستخدم الـ ID كما هو.
            let targetHomeId = (currentHomeId == "1") ? uid : currentHomeId
            
            db.collection("households").document(targetHomeId).addSnapshotListener { snapshot, error in
                
                // 🚨 حالة 1: الوثيقة غير موجودة (أو حدث خطأ)
                guard let data = snapshot?.data(), error == nil else {
                    if self.currentHomeId == "1" {
                        // إذا كنت في بيتك الرئيسي وما في وثيقة لسا، نعرض اسم افتراضي
                        self.members = [FamilyMember(email: self.currentUserEmail, role: "Owner", status: "Active")]
                        self.currentHomeName = "My Home" // ✅ الحل: تحديث الاسم يدوياً هنا
                    } else {
                        self.members = []
                        self.currentHomeName = "Unknown Home"
                    }
                    return
                }
                
                // 🚨 حالة 2: الوثيقة موجودة (جلبنا البيانات بنجاح)
                let owner = data["ownerEmail"] as? String ?? ""
                let membersList = data["members"] as? [String] ?? []
                let homeName = data["homeName"] as? String ?? "My Home" // قراءة الاسم
                
                var fetchedMembers: [FamilyMember] = []
                
                // إضافة المالك
                fetchedMembers.append(FamilyMember(email: owner, role: "Owner", status: "Active"))
                
                // إضافة البقية
                for memEmail in membersList where memEmail != owner {
                    fetchedMembers.append(FamilyMember(email: memEmail, role: "Member", status: "Active"))
                }
                
                DispatchQueue.main.async {
                    self.members = fetchedMembers
                    self.currentHomeName = homeName // ✅ الحل: تحديث الاسم من الداتا بيز
                }
            }
        }
    
    // MARK: - 2. جلب الدعوات الواردة
    func fetchIncomingInvites() {
        db.collection("invitations")
            .whereField("receiverEmail", isEqualTo: currentUserEmail)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.incomingInvites = docs.map { doc in
                        let data = doc.data()
                        return IncomingInvite(
                            id: doc.documentID,
                            fromHomeName: data["homeName"] as? String ?? "Unknown Home",
                            ownerEmail: data["senderEmail"] as? String ?? "Unknown"
                        )
                    }
                }
            }
    }
    
    // MARK: - 3. إرسال دعوة
    func sendInvite(to email: String, homeName: String) {
        isLoading = true
        
        ensureHouseholdExists { [weak self] homeId in
            guard let self = self, let homeId = homeId else {
                self?.isLoading = false
                return
            }
            
            let inviteData: [String: Any] = [
                "senderEmail": self.currentUserEmail,
                "receiverEmail": email.lowercased(),
                "homeId": homeId,
                "homeName": homeName,
                "status": "pending",
                "timestamp": FieldValue.serverTimestamp()
            ]
            
            self.db.collection("invitations").addDocument(data: inviteData) { error in
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Failed to send invite: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - 4. الاستجابة للدعوة
    func respondToInvite(_ invite: IncomingInvite, accept: Bool) {
        let status = accept ? "accepted" : "rejected"
        
        // 1. تحديث حالة الدعوة
        db.collection("invitations").document(invite.id).updateData(["status": status])
        
        if accept {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            db.collection("invitations").document(invite.id).getDocument { [weak self] doc, error in
                guard let self = self, let data = doc?.data(), error == nil else { return }
                
                let homeId = data["homeId"] as? String ?? ""
                let homeName = data["homeName"] as? String ?? "New Home"
                
                // 2. إضافة المستخدم لقائمة أعضاء البيت
                self.db.collection("households").document(homeId).updateData([
                    "members": FieldValue.arrayUnion([self.currentUserEmail])
                ])
                
                // 3. إضافة البيت لقائمة بيوت المستخدم (للداشبورد)
                let newHomeEntry: [String: String] = [
                    "homeId": homeId,
                    "homeName": homeName,
                    "role": "Member"
                ]
                
                self.db.collection("users").document(uid).updateData([
                    "joinedHomes": FieldValue.arrayUnion([newHomeEntry])
                ])
            }
        }
    }
    
    func updateHomeName(newName: String) {
            guard !newName.isEmpty, currentHomeId == "1", let uid = Auth.auth().currentUser?.uid else { return }
            
            isLoading = true
            
            // 1. تحديث الاسم في وثيقة البيت (Households)
            db.collection("households").document(uid).updateData(["homeName": newName]) { [weak self] error in
                if let error = error {
                    self?.errorMessage = "Failed to update name: \(error.localizedDescription)"
                    self?.isLoading = false
                    return
                }
                
                // 2. تحديث الاسم في وثيقة المستخدم (Users) عشان القائمة المنسدلة
                self?.db.collection("users").document(uid).getDocument { doc, _ in
                    if let data = doc?.data(), var joinedHomes = data["joinedHomes"] as? [[String: String]] {
                        
                        // نعدل الاسم داخل المصفوفة
                        for i in 0..<joinedHomes.count {
                            if joinedHomes[i]["homeId"] == "1" || joinedHomes[i]["homeId"] == uid {
                                joinedHomes[i]["homeName"] = newName
                            }
                        }
                        
                        // نحفظ المصفوفة المعدلة
                        self?.db.collection("users").document(uid).updateData(["joinedHomes": joinedHomes]) { _ in
                            DispatchQueue.main.async {
                                self?.currentHomeName = newName // تحديث الواجهة فوراً
                                self?.isLoading = false
                            }
                        }
                    }
                }
            }
        }
    
    // دالة مساعدة: التأكد من وجود وثيقة للبيت
    private func ensureHouseholdExists(completion: @escaping (String?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { completion(nil); return }

        // إذا كنت أنا المالك (في البيت رقم 1)، فمعرف البيت هو الـ UID تبعي
        if currentHomeId == "1" {
            let householdRef = db.collection("households").document(uid)
            
            householdRef.getDocument { doc, error in
                if let doc = doc, doc.exists {
                    completion(uid)
                } else {
                    // إنشاء وثيقة بيت جديدة
                    householdRef.setData([
                        "ownerEmail": self.currentUserEmail,
                        "homeName": "My Sweet Home",
                        "members": [self.currentUserEmail]
                    ]) { _ in
                        completion(uid)
                    }
                }
            }
        } else {
            // إذا كنت في بيت ثاني، بستخدم المعرف الموجود أصلاً
            completion(currentHomeId)
        }
    }
    // MARK: - 5. مغادرة المنزل (Leave Home)
        func leaveHome(completion: @escaping (Bool) -> Void) {
            guard let uid = Auth.auth().currentUser?.uid, currentHomeId != "1" else { return }
            
            let homeIdToLeave = currentHomeId
            let emailToRemove = currentUserEmail
            
            isLoading = true
            
            // 1. حذف العضو من وثيقة البيت (Household)
            db.collection("households").document(homeIdToLeave).updateData([
                "members": FieldValue.arrayRemove([emailToRemove])
            ]) { [weak self] error in
                if let error = error {
                    self?.errorMessage = "Failed to leave household: \(error.localizedDescription)"
                    self?.isLoading = false
                    completion(false)
                    return
                }
                
                // 2. حذف البيت من وثيقة المستخدم (User Profile)
                // ملاحظة: لإزالة عنصر من مصفوفة Map في فايربيس، يجب تمرير العنصر كاملاً بدقة
                // لذلك سنجلب البيانات أولاً لنعرف العنصر ونحذفه
                self?.db.collection("users").document(uid).getDocument { doc, _ in
                    if let data = doc?.data(), let joinedHomes = data["joinedHomes"] as? [[String: String]] {
                        
                        // البحث عن العنصر الذي يحتوي على نفس الـ ID
                        if let homeEntryToRemove = joinedHomes.first(where: { $0["homeId"] == homeIdToLeave }) {
                            
                            self?.db.collection("users").document(uid).updateData([
                                "joinedHomes": FieldValue.arrayRemove([homeEntryToRemove])
                            ]) { _ in
                                // 3. النجاح! إعادة المستخدم للبيت الرئيسي
                                DispatchQueue.main.async {
                                    self?.currentHomeId = "1" // العودة للبيت الافتراضي
                                    self?.isLoading = false
                                    completion(true)
                                }
                            }
                        } else {
                            self?.isLoading = false
                            completion(false)
                        }
                    }
                }
            }
        }
    
    // MARK: - 6. حذف عضو (للأدمن فقط)
        func removeMember(email: String) {
            guard currentHomeId == "1", let myUid = Auth.auth().currentUser?.uid else { return }
            
            isLoading = true
            
            // 1. حذف الإيميل من قائمة البيت (Households)
            // بما أنك الأدمن، فالبيت هو الـ UID تبعك
            let homeRef = db.collection("households").document(myUid)
            
            homeRef.updateData([
                "members": FieldValue.arrayRemove([email])
            ]) { [weak self] error in
                if let error = error {
                    self?.errorMessage = "Failed to remove from house: \(error.localizedDescription)"
                    self?.isLoading = false
                    return
                }
                
                // 2. (الحركة الذكية) البحث عن العضو لحذف البيت من عنده
                self?.db.collection("users").whereField("email", isEqualTo: email).getDocuments { snapshot, error in
                    guard let doc = snapshot?.documents.first else {
                        // العضو انحذف من البيت، بس ما لقينا بروفايله (ممكن محذوف أصلاً)
                        print("User profile not found, but removed from house list.")
                        self?.isLoading = false
                        return
                    }
                    
                    // لقينا العضو! هسا بنجيب مصفوفة بيوته وبنفلترها
                    let userId = doc.documentID
                    if let joinedHomes = doc.data()["joinedHomes"] as? [[String: String]] {
                        
                        // نحذف البيت اللي الـ ID تبعه هو الـ UID تبعي (لأني أنا المالك)
                        let updatedHomes = joinedHomes.filter { $0["homeId"] != myUid }
                        
                        // تحديث بروفايل العضو
                        self?.db.collection("users").document(userId).updateData([
                            "joinedHomes": updatedHomes
                        ]) { _ in
                            DispatchQueue.main.async {
                                self?.isLoading = false
                                // تحديث القائمة المحلية
                                self?.fetchMembers()
                            }
                        }
                    } else {
                        self?.isLoading = false
                    }
                }
            }
        }
}
