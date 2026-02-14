//
//  EmailLoginView.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 2/14/26.
//

import SwiftUI
import Supabase

struct EmailLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    
    // 심사위원이 입력할 상태값
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var message: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 배경색 (앱의 전체 톤과 맞춤)
                Color(red: 0.98, green: 0.96, blue: 0.94)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // 상단 설명
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(Color("MundapjipMain"))
                        
                        Text("이메일로 로그인")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("애플 심사위원 전용 로그인 화면입니다.\n제공된 테스트 계정 정보를 입력해주세요.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // 입력 필드
                    VStack(spacing: 16) {
                        TextField("이메일", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )

                        SecureField("비밀번호", text: $password)
                            .padding()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)

                    // 로그인 버튼
                    Button {
                        Task { await performSignIn() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 8)
                            }
                            Text("로그인")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(email.isEmpty || password.isEmpty ? Color.brandPrimaryDim : Color.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .padding(.horizontal, 24)

                    // 에러 메시지 표시
                    if let message {
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 32)
                    }

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - 로그인 로직 수행
    @MainActor
    private func performSignIn() async {
        guard !email.isEmpty, !password.isEmpty else { return }
        
        isLoading = true
        message = nil
        
        do {
            print("📨 [심사] 로그인 시도 중...")
            
            // 1. SessionManager에 정의된 이메일 로그인 함수 호출
            try await session.signIn(email: email, password: password)
            
            // 2. 심사위원을 위한 가족 데이터 생성/확인 RPC 호출
            // session 내의 client를 직접 활용합니다.
            let _: String = try await session.client
                .rpc("ensure_family_for_user")
                .execute()
                .value
            
            print("👍 [심사] 로그인 및 가족 데이터 보장 완료")
            
            // 3. 성공 시 모달 닫기
            // SessionManager의 auth상태가 바뀌었으므로 RootView에서 자동으로 메인으로 이동합니다.
            dismiss()
            
        } catch {
            print("❌ [심사] 로그인 실패: \(error.localizedDescription)")
            message = "로그인에 실패했습니다. 계정 정보를 다시 확인하거나 네트워크를 점검해주세요."
        }
        
        isLoading = false
    }
}


