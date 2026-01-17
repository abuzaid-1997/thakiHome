//
//  EditProfileView.swift
//  thakiHome
//
//  Created by Mohamad Abuzaid on 12/01/2026.
//
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct EditProfileView: View {
    @Environment(\.presentationMode) var mode
    
    // نستقبل البيانات الحالية لنعرضها
    @State var fullName: String
    @State var phone: String
    @State var country: String
    @State var city: String
    
    @State private var isLoading = false
    @State private var message = ""
    @State private var showSuccess = false
    
    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // ترويسة بسيطة
                Text("Edit Profile")
                    .font(.title2).bold()
                    .foregroundColor(.textPrimary)
                    .padding(.top)
                
                ScrollView {
                    VStack(spacing: 15) {
                        // حقل الاسم
                        customTextField(title: "Full Name", icon: "person.fill", text: $fullName)
                        
                        // حقل الهاتف
                        customTextField(title: "Phone Number", icon: "phone.fill", text: $phone)
                            .keyboardType(.phonePad)
                        
                        // حقل الدولة
                        customTextField(title: "Country", icon: "flag.fill", text: $country)
                        
                        // حقل المدينة
                        customTextField(title: "City", icon: "building.2.fill", text: $city)
                    }
                    .padding()
                }
                
                // رسائل الخطأ أو النجاح
                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(showSuccess ? .green : .red)
                        .font(.caption)
                }
                
                // زر الحفظ
                Button(action: saveProfile) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save Changes")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.mainPurple)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
    
    // تصميم الحقل الموحد
    func customTextField(title: String, icon: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundColor(.textSecondary)
            HStack {
                Image(systemName: icon).foregroundColor(.mainPurple).frame(width: 25)
                TextField(title, text: text)
                    .foregroundColor(.textPrimary)
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
    }
    
    // دالة الحفظ
    // دالة الحفظ (النسخة الآمنة والمعدلة)
        func saveProfile() {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            isLoading = true
            message = ""
            
            let data: [String: Any] = [
                "full_name": fullName,
                "phone": phone,
                "country": country,
                "city": city,
                "email": Auth.auth().currentUser?.email ?? "" // بنحفظ الإيميل كمان احتياط
            ]
            
            // التعديل هنا: استخدمنا setData مع merge بدلاً من updateData
            Firestore.firestore().collection("users").document(uid).setData(data, merge: true) { error in
                isLoading = false
                if let error = error {
                    message = "Error: \(error.localizedDescription)"
                    showSuccess = false
                } else {
                    message = "Profile updated successfully!"
                    showSuccess = true
                    
                    // تحديث الواجهة وتسكير الصفحة
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        mode.wrappedValue.dismiss()
                    }
                }
            }
        }
}
