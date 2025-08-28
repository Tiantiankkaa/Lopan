//
//  LoginView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authService: AuthenticationService
    @State private var wechatId = ""
    @State private var name = ""
    @State private var phone = ""
    @State private var showingDemoLogin = false
    @State private var showingSMSLogin = false
    @State private var selectedAuthMethod = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("洛盘生产管理系统")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("请使用微信登录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Authentication Methods
                VStack(spacing: 20) {
                    // Apple Sign In
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            Task {
                                await authService.loginWithApple(result: result)
                            }
                        }
                    )
                    .frame(height: 50)
                    .cornerRadius(10)
                    .padding(.horizontal, 40)
                    
                    // SMS Login Button
                    Button(action: {
                        showingSMSLogin = true
                    }) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("手机号登录")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    
                    // WeChat Login (Simulated)
                    if selectedAuthMethod == 2 {
                        VStack(spacing: 15) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("微信ID")
                                    .font(.headline)
                                TextField("请输入微信ID", text: $wechatId)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("姓名")
                                    .font(.headline)
                                TextField("请输入姓名", text: $name)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            Button(action: {
                                Task {
                                    await authService.loginWithWeChat(
                                        wechatId: wechatId,
                                        name: name,
                                        phone: phone.isEmpty ? nil : phone
                                    )
                                }
                            }) {
                                HStack {
                                    if authService.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "message.fill")
                                        Text("微信登录")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(wechatId.isEmpty || name.isEmpty || authService.isLoading)
                        }
                        .padding(.horizontal, 40)
                    } else {
                        Button("更多登录方式") {
                            selectedAuthMethod = 2
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                // Demo Login Button - Only available in DEBUG builds
                #if DEBUG
                Button("演示登录") {
                    showingDemoLogin = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                #endif
                
                Spacer()
                
                // Footer
                Text("© 2025 洛盘科技有限公司")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        #if DEBUG
        .sheet(isPresented: $showingDemoLogin) {
            DemoLoginView(authService: authService)
        }
        #endif
        .sheet(isPresented: $showingSMSLogin) {
            SMSLoginView(authService: authService)
        }
        .sheet(isPresented: $authService.showingSMSVerification) {
            SMSVerificationView(authService: authService)
        }
    }
}

struct DemoLoginView: View {
    @ObservedObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: UserRole = .salesperson
    @State private var isLoggingIn = false
    @State private var loginError: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("演示登录")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("⚠️ 仅限开发环境使用")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                
                Text("选择角色进行演示")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    ForEach(UserRole.allCases.filter { $0 != .unauthorized }, id: \.self) { role in
                        Button(action: {
                            selectedRole = role
                        }) {
                            HStack {
                                Text(role.displayName)
                                Spacer()
                                if selectedRole == role {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(selectedRole == role ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                Button("开始演示") {
                    Task { @MainActor in
                        do {
                            isLoggingIn = true
                            loginError = nil
                            
                            // 演示登录 - 仅开发环境
                            await authService.loginWithWeChat(
                                wechatId: "demo_\(selectedRole.rawValue)",
                                name: "演示用户 - \(selectedRole.displayName)",
                                phone: nil
                            )
                            
                            // TODO: In demo mode, manually set role after login for testing purposes only
                            // In production, role assignment requires proper authorization
                            #if DEBUG
                            if let user = authService.currentUser {
                                await MainActor.run {
                                    authService.updateUserRoles([selectedRole], primaryRole: selectedRole)
                                }
                            }
                            #endif
                            
                            // 检查登录是否成功
                            if authService.isAuthenticated {
                                // 登录完成后关闭视图
                                dismiss()
                            } else {
                                loginError = "登录失败，请重试"
                            }
                        } catch {
                            loginError = "登录出错: \(error.localizedDescription)"
                        }
                        isLoggingIn = false
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background((isLoggingIn || authService.isLoading) ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isLoggingIn || authService.isLoading)
                .padding(.horizontal)
                
                // Loading indicator
                if isLoggingIn || authService.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在登录...")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Error message
                if let errorMessage = loginError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("演示登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SMSLoginView: View {
    @ObservedObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @State private var phoneNumber = ""
    @State private var name = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("手机号登录")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("请输入手机号和姓名")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("手机号")
                            .font(.headline)
                        TextField("请输入手机号", text: $phoneNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.phonePad)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("姓名")
                            .font(.headline)
                        TextField("请输入姓名", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal)
                
                Button("发送验证码") {
                    Task {
                        await authService.sendSMSCode(to: phoneNumber, name: name)
                        await MainActor.run {
                            dismiss()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(phoneNumber.count >= 11 && !name.isEmpty ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(phoneNumber.count < 11 || name.isEmpty || authService.isLoading)
                .padding(.horizontal)
                
                if authService.isLoading {
                    ProgressView("发送中...")
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("手机号登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SMSVerificationView: View {
    @ObservedObject var authService: AuthenticationService
    @State private var verificationCode = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("验证码验证")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("验证码已发送至 \(authService.phoneNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("演示模式：请输入 1234")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                
                TextField("请输入验证码", text: $verificationCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("验证") {
                    Task {
                        await authService.verifySMSCode(verificationCode)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(verificationCode.count >= 4 ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(verificationCode.count < 4 || authService.isLoading)
                .padding(.horizontal)
                
                if authService.isLoading {
                    ProgressView("验证中...")
                        .padding()
                }
                
                Button("重新发送验证码") {
                    // In production, implement resend logic
                    print("重新发送验证码")
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Spacer()
            }
            .padding()
            .navigationTitle("验证码")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
    LoginView(authService: AuthenticationService(repositoryFactory: repositoryFactory))
} 