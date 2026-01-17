import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// --- Data Models (تأكد أنها غير مكررة إذا نقلتها لملف Models) ---
struct FamilyMember: Identifiable {
    let id = UUID()
    let email: String
    let role: String   // "Owner" or "Member"
    let status: String // "Active" or "Pending"
}

struct IncomingInvite: Identifiable {
    let id: String     // Document ID
    let fromHomeName: String
    let ownerEmail: String
}

// --- Main View ---
struct FamilyManagementView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = FamilyViewModel()
    
    // متغيرات التعديل
    @State private var showRenameAlert = false
    @State private var newHomeName = ""
    
    // متغيرات إضافة عضو
    @State private var newMemberEmail = ""
    @State private var showAddSheet = false
    
    @State private var showLeaveConfirmation = false
    
    let currentUserEmail = Auth.auth().currentUser?.email ?? ""
    
    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "arrow.backward")
                            .font(.title2)
                            .foregroundColor(.textPrimary)
                    }
                    Text("Family Management")
                        .font(.title3).bold()
                        .foregroundColor(.textPrimary)
                    Spacer()
                }
                .padding()
                .background(Color.themeBackground)
                
                ScrollView {
                    VStack(spacing: 25) {
                        
                        // ✅ قسم اسم البيت (مع زر التعديل للأدمن)
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Home Name")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(viewModel.currentHomeName)
                                    .font(.title2).bold()
                                    .foregroundColor(.mainPurple)
                            }
                            Spacer()
                            
                            // يظهر القلم فقط للأدمن
                            if viewModel.currentHomeId == "1" {
                                Button(action: {
                                    newHomeName = viewModel.currentHomeName
                                    showRenameAlert = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.mainPurple)
                                }
                            }
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // MARK: - 1. الدعوات الواردة
                        if !viewModel.incomingInvites.isEmpty {
                            // ... (نفس الكود السابق للدعوات)
                            VStack(alignment: .leading, spacing: 15) {
                                Text("New Invitations").font(.headline).foregroundColor(.mainPurple).padding(.horizontal)
                                ForEach(viewModel.incomingInvites) { invite in
                                    IncomingInviteCard(invite: invite, onAccept: { viewModel.respondToInvite(invite, accept: true) }, onDecline: { viewModel.respondToInvite(invite, accept: false) })
                                }
                            }
                        }
                        
                        // MARK: - 2. أعضاء المنزل
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Home Members").font(.headline).foregroundColor(.textPrimary)
                                Spacer()
                                if viewModel.currentHomeId == "1" {
                                    Button(action: { showAddSheet = true }) {
                                        Label("Add Member", systemImage: "person.badge.plus")
                                            .font(.caption).bold().padding(8).background(Color.mainPurple.opacity(0.1)).foregroundColor(.mainPurple).cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                                        ForEach(viewModel.members, id: \.email) { member in
                                                            MemberRow(
                                                                email: member.email,
                                                                role: member.role,
                                                                status: member.status,
                                                                isCurrentUser: member.email == currentUserEmail,
                                                                canDelete: (viewModel.currentHomeId == "1" && member.email != currentUserEmail)
                                                            ) {
                                                                // 👇 هذا هو التعديل الصحيح (بدون تكرار)
                                                                viewModel.removeMember(email: member.email)
                                                            }
                                                        }
                                                    }
                                                    .padding(.horizontal)
                        }
                        
                        // زر Leave Home
                        if viewModel.currentHomeId != "1" {
                            Button(action: {
                                showLeaveConfirmation = true // 👈 بس بنغير الحالة لتظهر الرسالة
                            }) {
                                Text("Leave Home")
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.9))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                    }
                    .padding(.bottom, 30)
                }
                .refreshable {
                    viewModel.fetchMembers()
                    viewModel.fetchIncomingInvites()
                }
            }
            .navigationBarHidden(true)
            
            // Loading Overlay
            if viewModel.isLoading { Color.black.opacity(0.3).ignoresSafeArea(); ProgressView().tint(.white) }
            
            // Sheet إضافة عضو (نفس الكود السابق)
            if showAddSheet {
                // ... (نفس كود الـ Sheet السابق)
                Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { showAddSheet = false }
                VStack(spacing: 20) {
                     Text("Invite Member").font(.title3).bold()
                     TextField("Email", text: $newMemberEmail).textFieldStyle(RoundedBorderTextFieldStyle()).autocapitalization(.none).padding()
                     Button("Send Invite") {
                         viewModel.sendInvite(to: newMemberEmail, homeName: viewModel.currentHomeName) // ✅ استخدام الاسم الحقيقي
                         showAddSheet = false
                         newMemberEmail = ""
                     }.padding().background(Color.mainPurple).foregroundColor(.white).cornerRadius(10)
                }.padding().background(Color.cardBackground).cornerRadius(20).padding(.horizontal)
            }
        }
        // ✅ Alert تعديل الاسم
        .alert("Change Home Name", isPresented: $showRenameAlert) {
            TextField("New Name", text: $newHomeName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                viewModel.updateHomeName(newName: newHomeName)
            }
        } message: {
            Text("Enter a new name for your home.")
        }
        
        // ✅ Alert تأكيد المغادرة
        .alert("Leave Home?", isPresented: $showLeaveConfirmation) {
            Button("Cancel", role: .cancel) { } // زر التراجع
            
            Button("Leave", role: .destructive) { // زر التنفيذ الحقيقي (لونه أحمر)
                viewModel.leaveHome { success in
                    if success { presentationMode.wrappedValue.dismiss() }
                }
            }
        } message: {
            Text("Are you sure you want to leave this home? You will lose access to all devices.")
        }
    }
}
// --- Components ---

// كرت الدعوة (UI)
struct IncomingInviteCard: View {
    let invite: IncomingInvite
    var onAccept: () -> Void
    var onDecline: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invite.fromHomeName)
                    .font(.headline).foregroundColor(.textPrimary)
                Text("Invited by \(invite.ownerEmail)")
                    .font(.caption).foregroundColor(.textSecondary)
            }
            Spacer()
            HStack(spacing: 10) {
                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .foregroundColor(.red)
                        .padding(10).background(Color.red.opacity(0.1)).clipShape(Circle())
                }
                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .padding(10).background(Color.green.opacity(0.1)).clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mainPurple.opacity(0.3), lineWidth: 1).padding(.horizontal))
    }
}

// سطر العضو (UI)
struct MemberRow: View {
    let email: String
    let role: String
    let status: String
    let isCurrentUser: Bool
    var canDelete: Bool = false
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(isCurrentUser ? Color.mainPurple : Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                Text(String(email.prefix(1)).uppercased())
                    .font(.headline).foregroundColor(isCurrentUser ? .white : .textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isCurrentUser ? "You" : email)
                    .font(.subheadline).bold().foregroundColor(.textPrimary)
                
                HStack(spacing: 5) {
                    Text(role)
                        .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(role == "Owner" ? Color.orange.opacity(0.2) : Color.blue.opacity(0.1))
                        .foregroundColor(role == "Owner" ? .orange : .blue)
                        .cornerRadius(4)
                    
                    if status == "Pending" {
                        Text("Pending")
                            .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2)).foregroundColor(.gray).cornerRadius(4)
                    }
                }
            }
            Spacer()
            
            if canDelete {
                Button(action: { onDelete?() }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.7)).padding(8)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}
