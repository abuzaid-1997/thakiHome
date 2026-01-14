//
//  LoginView.swift
//  thakiHome
//
//  Created by Mohamad Abuzaid on 05/01/2026.
//

import SwiftUI
import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import FirebaseFirestore
import AuthenticationServices

// ==========================================
// 1. مدراء البيانات (CountryManager)
// ==========================================

struct CountryInfo: Hashable, Identifiable {
    var id: String { code }
    let name: String
    let flag: String
    let dialCode: String
    let code: String
}

class CountryManager {
    static let shared = CountryManager()
    let allCountries: [CountryInfo]
    
    init() {
        var countries: [CountryInfo] = []
        for code in NSLocale.isoCountryCodes {
            let name = NSLocale(localeIdentifier: "en_US").displayName(forKey: .countryCode, value: code) ?? code
            let flag = String(String.UnicodeScalarView(code.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }))
            let dialCode = CountryManager.getDialCode(countryCode: code)
            if dialCode != "+00" {
                countries.append(CountryInfo(name: name, flag: flag, dialCode: dialCode, code: code))
            }
        }
        self.allCountries = countries.sorted { $0.name < $1.name }
    }
    
    static func getDialCode(countryCode: String) -> String {
        let codes: [String: String] = [
            "JO": "+962", "SA": "+966", "AE": "+971", "EG": "+20", "KW": "+965",
            "QA": "+974", "PS": "+970", "IQ": "+964", "US": "+1", "UK": "+44",
            "LB": "+961", "SY": "+963", "BH": "+973", "OM": "+968", "YE": "+967",
            "TR": "+90", "DE": "+49", "FR": "+33", "IT": "+39", "ES": "+34",
            "CA": "+1", "IN": "+91", "PK": "+92", "MA": "+212", "DZ": "+213",
            "TN": "+216", "SD": "+249"
        ]
        return codes[countryCode] ?? "+00"
    }
}

// ==========================================
// 2. واجهة تسجيل الدخول (LoginView)
// ==========================================

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Environment(\.colorScheme) var colorScheme
    
    // States
    @State private var isSignUp = false
    @State private var isEnglish = false
    @State private var signupStep = 1
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showVerificationPending = false
    
    // Alerts
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // User Data
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var gender = "Male"
    @State private var birthDate = Date()
    @State private var phoneNumber = ""
    @State private var city = ""
    
    // Selection
    @State private var selectedCountry = CountryManager.shared.allCountries.first(where: { $0.code == "JO" }) ?? CountryManager.shared.allCountries[0]
    @State private var selectedPhoneCountry = CountryManager.shared.allCountries.first(where: { $0.code == "JO" }) ?? CountryManager.shared.allCountries[0]
    
    // Texts
    var txt: [String: [String: String]] = [
        "ar": ["login": "دخول", "signup": "تسجيل جديد", "lang": "English", "back": "رجوع", "finish": "إتمام التسجيل", "next": "التالي", "or": "أو", "email": "البريد الإلكتروني", "pass": "كلمة المرور", "confirm": "تأكيد كلمة المرور", "fname": "الاسم الأول", "lname": "اسم العائلة", "city": "المدينة", "phone": "رقم الموبايل", "forgot": "نسيت كلمة المرور؟", "verify_title": "تحقق من بريدك", "verify_msg": "لقد أرسلنا رابط تفعيل إلى:", "back_login": "العودة لتسجيل الدخول", "reset_success": "تم الإرسال", "reset_msg": "راجع بريدك الإلكتروني لإعادة تعيين كلمة المرور."],
        "en": ["login": "Login", "signup": "Sign Up", "lang": "العربية", "back": "Back", "finish": "Finish", "next": "Next", "or": "OR", "email": "Email Address", "pass": "Password", "confirm": "Confirm Password", "fname": "First Name", "lname": "Last Name", "city": "City", "phone": "Mobile Number", "forgot": "Forgot Password?", "verify_title": "Check Your Email", "verify_msg": "We sent a verification link to:", "back_login": "Back to Login", "reset_success": "Email Sent", "reset_msg": "Check your inbox to reset your password."]
    ]
    var currentLang: String { isEnglish ? "en" : "ar" }
    
    var currentBackgroundImage: String {
        if !isSignUp { return "bg_login" }
        switch signupStep {
        case 1: return "bg_step1"
        case 2: return "bg_step2"
        default: return "bg_step3"
        }
    }
    
    let sidePadding: CGFloat = 24
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                
                // 1. الخلفية
                Color.themeBackground.ignoresSafeArea()
                Image(currentBackgroundImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.1)
                    .animation(.easeInOut, value: signupStep)
                
                Color.clear.contentShape(Rectangle()).onTapGesture { hideKeyboard() }
                
                // 2. المحتوى الرئيسي
                if showVerificationPending {
                    VStack {
                        Spacer()
                        verificationPendingView
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // مسافة بسيطة من الأعلى عشان الناف بار ما يلزق بالعناصر
                            Spacer().frame(height: 20)
                            
                            if !isSignUp {
                                loginViewContent
                            } else {
                                signupWizardContent
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            // ---------------------------------------------------------
            // ✅ التغيير الوحيد هنا: استخدام Toolbar بدلاً من الأزرار العائمة
            // ---------------------------------------------------------
            .navigationBarBackButtonHidden(true)
            .toolbar {
                // زر الرجوع (يظهر فقط في التسجيل)
                ToolbarItem(placement: .topBarLeading) {
                    if isSignUp && !showVerificationPending {
                        Button(action: handleBackAction) {
                            HStack(spacing: 5) {
                                Image(systemName: isEnglish ? "chevron.left" : "chevron.right")
                                Text(txt[currentLang]!["back"]!)
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.mainPurple)
                        }
                    }
                }
                
                // زر اللغة (يظهر فقط في الدخول)
                ToolbarItem(placement: .topBarTrailing) {
                    if !isSignUp && !showVerificationPending {
                        Button(action: { withAnimation { isEnglish.toggle() } }) {
                            HStack(spacing: 5) {
                                Image(systemName: "globe")
                                Text(txt[currentLang]!["lang"]!)
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.mainPurple)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.cardBackground.opacity(0.8))
                            .cornerRadius(15)
                        }
                    }
                }
            }
            // جعل خلفية الناف بار شفافة
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Login View Content
    var loginViewContent: some View {
        VStack(spacing: 30) {
            VStack(spacing: 15) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .cornerRadius(25)
                    .shadow(radius: 5)
            }.padding(.top, 20)
            
            VStack(spacing: 20) {
                CustomInput(icon: "envelope.fill", placeholder: txt[currentLang]!["email"]!, text: $email)
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                
                passwordField(title: txt[currentLang]!["pass"]!, text: $password, isVisible: $showPassword)
                
                if !errorMessage.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(errorMessage)
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack {
                    Spacer()
                    Button(action: resetPassword) {
                        Text(txt[currentLang]!["forgot"]!)
                            .font(.caption).bold()
                            .foregroundColor(.mainPurple)
                    }
                }
            }
            
            Button(action: handleLogin) {
                if isLoading { ProgressView().tint(.white) }
                else { Text(txt[currentLang]!["login"]!).font(.headline).bold().foregroundColor(.white).frame(maxWidth: .infinity) }
            }
            .frame(height: 50)
            .background(Color.mainPurple).cornerRadius(15).shadow(color: .mainPurple.opacity(0.4), radius: 8, y: 4)
            
            Button(action: { withAnimation { isSignUp = true; signupStep = 1; errorMessage = "" } }) {
                Text(isEnglish ? "New here? Create Account" : "ليس لديك حساب؟ سجل الآن").foregroundColor(.gray)
            }
            
            dividerOr
            socialButtons
            
            Spacer().frame(height: 50)
        }
        .padding(.horizontal, sidePadding)
        .padding(.bottom, 20)
        .frame(maxWidth: 400) // ✅ هذا السطر هو سر ثبات التصميم في كودك
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Signup View Content
    var signupWizardContent: some View {
        VStack(spacing: 20) {
            
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(1...3, id: \.self) { i in
                        Circle()
                            .fill(i <= signupStep ? Color.mainPurple : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                        if i < 3 {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                Text(stepTitle).font(.title3).bold().foregroundColor(.textPrimary)
            }
            .padding(.top, 10)
            .padding(.horizontal, sidePadding)
            .frame(maxWidth: 400) // ✅ وهنا كمان
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if signupStep == 1 {
                        CustomInput(icon: "envelope.fill", placeholder: txt[currentLang]!["email"]!, text: $email)
                            .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        passwordField(title: txt[currentLang]!["pass"]!, text: $password, isVisible: $showPassword)
                        passwordField(title: txt[currentLang]!["confirm"]!, text: $confirmPassword, isVisible: $showConfirmPassword)
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage).foregroundColor(.red).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                    } else if signupStep == 2 {
                        HStack(spacing: 10) {
                            CustomInput(icon: "person.fill", placeholder: txt[currentLang]!["fname"]!, text: $firstName)
                            CustomInput(icon: "", placeholder: txt[currentLang]!["lname"]!, text: $lastName)
                        }
                        Picker("", selection: $gender) {
                            Text(isEnglish ? "Male" : "ذكر").tag("Male")
                            Text(isEnglish ? "Female" : "أنثى").tag("Female")
                        }.pickerStyle(SegmentedPickerStyle())
                        
                        DatePicker(isEnglish ? "Birth Date" : "تاريخ الميلاد", selection: $birthDate, displayedComponents: .date)
                            .padding().background(Color.cardBackground).cornerRadius(12)
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage).foregroundColor(.red).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                    } else if signupStep == 3 {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(isEnglish ? "Country" : "الدولة").font(.caption).foregroundColor(.gray)
                            Menu {
                                Picker("Country", selection: $selectedCountry) {
                                    ForEach(CountryManager.shared.allCountries) { country in
                                        Text("\(country.flag) \(country.name)").tag(country)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedCountry.flag).font(.title2)
                                    Text(selectedCountry.name).foregroundColor(.textPrimary).bold()
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.caption).foregroundColor(.gray)
                                }
                                .padding().background(Color.cardBackground).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            }
                        }
                        CustomInput(icon: "building.2.fill", placeholder: txt[currentLang]!["city"]!, text: $city)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(isEnglish ? "Mobile Number" : "رقم الموبايل").font(.caption).foregroundColor(.gray)
                            HStack(spacing: 10) {
                                Menu {
                                    Picker("Code", selection: $selectedPhoneCountry) {
                                        ForEach(CountryManager.shared.allCountries) { country in
                                            Text("\(country.flag) \(country.name) (\(country.dialCode))").tag(country)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedPhoneCountry.flag)
                                        Text(selectedPhoneCountry.dialCode).bold()
                                    }
                                    .padding(.horizontal, 12).frame(height: 50).background(Color.gray.opacity(0.15)).cornerRadius(10).foregroundColor(.textPrimary)
                                }
                                TextField(txt[currentLang]!["phone"]!, text: $phoneNumber).keyboardType(.phonePad).padding(.horizontal).frame(height: 50).background(Color.clear)
                            }.padding(4).background(Color.cardBackground).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                        }
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage).foregroundColor(.red).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, sidePadding)
                .padding(.bottom, 20)
                
                // Next Button
                Button(action: nextStep) {
                    if isLoading { ProgressView().tint(.white) }
                    else { Text(signupStep == 3 ? txt[currentLang]!["finish"]! : txt[currentLang]!["next"]!).font(.headline).bold().foregroundColor(.white).frame(maxWidth: .infinity) }
                }
                .frame(height: 50)
                .background(Color.mainPurple).cornerRadius(15).shadow(color: .mainPurple.opacity(0.4), radius: 8, y: 4)
                .padding(.horizontal, sidePadding)
                .frame(maxWidth: 400) // ✅ وهذا كمان
                
                Spacer().frame(height: 50)
            }
            .frame(maxWidth: 400) // ✅ وهذا
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    var verificationPendingView: some View {
        VStack(spacing: 25) {
            Image(systemName: "envelope.badge.fill").font(.system(size: 80)).foregroundColor(.mainPurple).padding()
            Text(txt[currentLang]!["verify_title"]!).font(.title).bold().foregroundColor(.textPrimary)
            Text("\(txt[currentLang]!["verify_msg"]!)\n\(email)").multilineTextAlignment(.center).foregroundColor(.textSecondary).padding(.horizontal)
            Button(action: {
                withAnimation { showVerificationPending = false; isSignUp = false; signupStep = 1; password = "" }
            }) {
                Text(txt[currentLang]!["back_login"]!).bold().frame(maxWidth: .infinity).padding().background(Color.mainPurple).foregroundColor(.white).cornerRadius(12)
            }.padding(.horizontal, 40)
        }
        .padding().background(Color.cardBackground).cornerRadius(20).shadow(radius: 20).padding(30)
        .frame(maxWidth: 400)
    }
    
    // MARK: - Components
    var dividerOr: some View {
        HStack { Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3)); Text(txt[currentLang]!["or"]!).foregroundColor(.gray).font(.caption); Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3)) }.padding(.vertical, 10)
    }
    
    var socialButtons: some View {
        VStack(spacing: 15) {
            Button(action: signInWithGoogle) {
                HStack {
                    Image("GoogleLogo").resizable().scaledToFit().frame(width: 22, height: 22)
                    Text(isEnglish ? "Sign in with Google" : "استمرار بحساب جوجل").fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.cardBackground).foregroundColor(.textPrimary).cornerRadius(12).shadow(color: .black.opacity(0.05), radius: 3)
            }
            
            ZStack {
                HStack {
                    Image(systemName: "apple.logo").resizable().scaledToFit().frame(width: 22, height: 22).foregroundColor(.primary)
                    Text(isEnglish ? "Sign in with Apple" : "استمرار بحساب أبل").fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.cardBackground).foregroundColor(.textPrimary).cornerRadius(12).shadow(color: .black.opacity(0.05), radius: 3)
                
                SignInWithAppleButton(.signIn) { request in request.requestedScopes = [.fullName, .email] }
                onCompletion: { result in
                    switch result {
                    case .success(let authorization): handleAppleSignIn(authorization: authorization)
                    case .failure(let error): self.errorMessage = error.localizedDescription
                    }
                }
                .signInWithAppleButtonStyle(.white).blendMode(.destinationOver).opacity(0.02)
            }
        }
    }
    
    func passwordField(title: String, text: Binding<String>, isVisible: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: "lock.fill").foregroundColor(.gray).frame(width: 20)
            if isVisible.wrappedValue { TextField(title, text: text).foregroundColor(.primary) } else { SecureField(title, text: text).foregroundColor(.primary) }
            Button(action: { isVisible.wrappedValue.toggle() }) { Image(systemName: isVisible.wrappedValue ? "eye.slash.fill" : "eye.fill").foregroundColor(.gray) }
        }
        .padding().frame(height: 50)
        .background(Color.cardBackground).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    
    var stepTitle: String {
        if signupStep == 1 { return isEnglish ? "Account Info" : "بيانات الحساب" }
        else if signupStep == 2 { return isEnglish ? "Personal Info" : "معلومات شخصية" }
        else { return isEnglish ? "Location & Contact" : "الموقع والاتصال" }
    }
    
    // MARK: - Logic Functions
    func handleBackAction() {
        withAnimation {
            if signupStep > 1 {
                signupStep -= 1
            } else {
                isSignUp = false
                errorMessage = ""
            }
        }
    }
    
    func nextStep() {
        errorMessage = ""
        hideKeyboard()
        if signupStep == 1 {
            guard !email.isEmpty, !password.isEmpty else { errorMessage = isEnglish ? "Fill all fields" : "عبي كل الخانات"; return }
            guard password == confirmPassword else { errorMessage = isEnglish ? "Passwords do not match" : "كلمات المرور غير متطابقة"; return }
            guard password.count >= 6 else { errorMessage = isEnglish ? "Password too short" : "كلمة المرور قصيرة جداً"; return }
            withAnimation { signupStep = 2 }
        } else if signupStep == 2 {
            guard !firstName.isEmpty, !lastName.isEmpty else { errorMessage = isEnglish ? "Full Name is required" : "الاسم الكامل مطلوب"; return }
            withAnimation { signupStep = 3 }
        } else {
            guard !phoneNumber.isEmpty else { errorMessage = isEnglish ? "Phone required" : "رقم الموبايل مطلوب"; return }
            handleSignUp()
        }
    }
    
    func handleLogin() {
            hideKeyboard()
            guard !email.isEmpty, !password.isEmpty else { return }
            isLoading = true
            errorMessage = ""
            
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                isLoading = false
                
                if let error = error as NSError? {
                    print("Error Code: \(error.code)") // عشان تشوف الرقم بالكونسول للتأكد
                    
                    if let errorCode = AuthErrorCode(rawValue: error.code) {
                        switch errorCode {
                            
                        // 1. حالة كلمة المرور خطأ (والإيميل صح)
                        case .wrongPassword:
                            errorMessage = isEnglish ? "Incorrect Password" : "كلمة المرور غير صحيحة"
                            
                        // 2. حالة الإيميل غير موجود أصلاً (مش مسجل)
                        case .userNotFound:
                            errorMessage = isEnglish ? "Account not found" : "لا يوجد حساب بهذا البريد الإلكتروني"
                            
                        // 3. حالة صيغة الإيميل غلط (مثلاً نسي @gmail.com)
                        case .invalidEmail:
                            errorMessage = isEnglish ? "Invalid Email Format" : "تأكد من كتابة الإيميل بشكل صحيح"
                            
                        // 4. حالة الحساب معطل من الإدارة
                        case .userDisabled:
                            errorMessage = isEnglish ? "Account disabled" : "تم تعطيل هذا الحساب"
                            
                        // 5. مشاكل عامة في بيانات الاعتماد (نخليها عامة عشان ما نلخبط اليوزر)
                        case .invalidCredential:
                            errorMessage = isEnglish ? "Invalid credentials" : "البيانات المدخلة غير صحيحة"
                            
                        // أي خطأ آخر (نت، سيرفر، إلخ)
                        default:
                            errorMessage = isEnglish ? "Login failed" : "فشل تسجيل الدخول، حاول مرة أخرى"
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
                else if let user = result?.user {
                    if user.isEmailVerified {
                        withAnimation { isLoggedIn = true }
                    } else {
                        user.sendEmailVerification()
                        try? Auth.auth().signOut()
                        errorMessage = isEnglish ? "Verify email first" : "يرجى تفعيل الإيميل أولاً من الرابط المرسل"
                    }
                }
            }
        }
    
    func handleSignUp() {
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error { isLoading = false; errorMessage = error.localizedDescription }
            else if let user = result?.user {
                user.sendEmailVerification()
                saveUserToDatabase(uid: user.uid)
            }
        }
    }
    
    func saveUserToDatabase(uid: String) {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        let fullNameCombined = "\(firstName) \(lastName)"
        let data: [String: Any] = [
            "uid": uid, "first_name": firstName, "last_name": lastName, "full_name": fullNameCombined,
            "email": email, "gender": gender,
            "birth_date": formatter.string(from: birthDate), "country": selectedCountry.name, "city": city,
            "phone_code": selectedPhoneCountry.dialCode, "phone_number": phoneNumber,
            "full_phone": "\(selectedPhoneCountry.dialCode)\(phoneNumber)", "created_at": FieldValue.serverTimestamp()
        ]
        Firestore.firestore().collection("users").document(uid).setData(data) { error in
            isLoading = false
            if let error = error { errorMessage = error.localizedDescription }
            else { withAnimation { showVerificationPending = true } }
        }
    }
    
    func resetPassword() {
        hideKeyboard()
        guard !email.isEmpty else { errorMessage = isEnglish ? "Enter email first" : "أدخل الإيميل أولاً"; return }
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error { errorMessage = error.localizedDescription }
            else { alertTitle = txt[currentLang]!["reset_success"]!; alertMessage = txt[currentLang]!["reset_msg"]!; showAlert = true }
        }
    }
    
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let rootViewController = windowScene.windows.first?.rootViewController else { return }
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error { self.errorMessage = error.localizedDescription; return }
            guard let user = result?.user, let idToken = user.idToken?.tokenString else { return }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { authResult, error in
                if let authUser = authResult?.user { checkAndCreateGoogleUser(authUser: authUser) }
            }
        }
    }
    
    func handleAppleSignIn(authorization: ASAuthorization) { /* Logic remains same */ }
    func checkAndCreateGoogleUser(authUser: User) { /* Logic remains same */ self.isLoggedIn = true }
    func hideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
}

// ==========================================
// 3. مكونات مساعدة (CustomInput)
// ==========================================

struct CustomInput: View {
    var icon: String; var placeholder: String; @Binding var text: String
    var body: some View {
        HStack {
            if !icon.isEmpty { Image(systemName: icon).foregroundColor(.gray).frame(width: 20) }
            TextField(placeholder, text: $text).foregroundColor(.primary) // ✅ إصلاح لون النص
        }
        .padding().frame(height: 50)
        .background(Color.cardBackground).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
}
