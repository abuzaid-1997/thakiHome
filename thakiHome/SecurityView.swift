//
//  SecurityView.swift
//  thakiHome
//
//  Created by Mohamad Abuzaid on 12/01/2026.
//

import SwiftUI
import FirebaseAuth

struct SecurityView: View {
    @State private var showConfirmation = false
    @State private var message = ""
    
    var userEmail: String {
        return Auth.auth().currentUser?.email ?? "your email"
    }
    
    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.mainPurple)
                    .padding(.top, 50)
                
                Text("Security & Privacy")
                    .font(.title2).bold()
                    .foregroundColor(.textPrimary)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Password Reset")
                        .font(.headline).foregroundColor(.textPrimary)
                    
                    Text("We will send a password reset link to:")
                        .foregroundColor(.textSecondary)
                    
                    Text(userEmail)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.textPrimary)
                        .padding(.vertical, 5)
                    
                    Button(action: {
                        sendResetEmail()
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Send Reset Link")
                        }
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cardBackground)
                        .foregroundColor(.red) // لون أحمر لأنه إجراء حساس
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                    }
                }
                .padding()
                .background(Color.cardBackground.opacity(0.5))
                .cornerRadius(15)
                .padding(.horizontal)
                
                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
        }
    }
    
    func sendResetEmail() {
        guard let email = Auth.auth().currentUser?.email else { return }
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                message = "Error: \(error.localizedDescription)"
            } else {
                message = "✅ Reset link sent! Check your inbox."
            }
        }
    }
}
