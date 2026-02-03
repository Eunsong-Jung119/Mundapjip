

//
//  LoginView.swift
//  Mundapjip
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var session: SessionManager

    private let appleManager = AppleSignInManager()
    private let buttonMaxWidth: CGFloat = 353


    // 상태
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = "로그인에 실패했어요. 잠시 후 다시 시도해주세요."

    var body: some View {
        ZStack {
            // ✅ 1) 배경을 Splash_Background 이미지로 교체
            Image("Splash_Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ✅ 2) 텍스트 로고 → 이미지 로고로 교체
                Image("Mundapjip_Logo_Text")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)

                Text("우리 가족의 이야기를 한 권으로")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.7))
                    .padding(.top, 24)

                Spacer()

                VStack(spacing: 16) {
                    appleButton
                        .disabled(isLoading)

                    kakaoButton
                        .disabled(isLoading)
                }
                .frame(maxWidth: buttonMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
            }
        }
        .alert("안내", isPresented: $showAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Apple Button

    private var appleButton: some View {
        AppleSignInButton(
            type: .continue,
            style: .black,
            cornerRadius: 12
        ) {
            // ✅ 기존 SignInWithAppleButton의 onRequest/onCompletion 로직은
            // 여기서 AppleSignInManager + ASAuthorizationController로 실행해야 함.
            // (아래에 "그대로 쓰는 방법"을 바로 적어둘게)
            Task { await startAppleLoginFlow() }
        }
        .frame(height: 56)
    }


    
    @MainActor
    private func startAppleLoginFlow() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await appleManager.signIn()
            try await session.signInWithApple(idToken: token.idToken, nonce: token.nonce)
        } catch {
            alertMessage = "애플 로그인에 실패했어요. 잠시 후 다시 시도해주세요."
            showAlert = true
        }
    }



    // MARK: - Kakao Button

    private var kakaoButton: some View {
        Button {
            Task {
                guard !isLoading else { return }
                isLoading = true
                defer { isLoading = false }

                do {
                    try await session.signInWithKakao()
                } catch {
                    alertMessage = "카카오 로그인에 실패했어요. 잠시 후 다시 시도해주세요."
                    showAlert = true
                }
            }
        } label: {
            Image("KakaoLoginButton")
                .resizable()
                .scaledToFit()
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview{
    LoginView()
}
