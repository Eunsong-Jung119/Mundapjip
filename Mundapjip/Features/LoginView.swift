

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
    
    // ✅ 1) 이메일 로그인 시트를 띄우기 위한 상태값 추가
    @State private var showEmailLogin = false

    var body: some View {
        ZStack {
            // 배경
            Image("Splash_Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 로고
                Image("Mundapjip_Logo_Text")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)

                Text("우리 가족의 이야기를 한 권으로")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.7))
                    .padding(.top, 24)

                Spacer()

                // 버튼 영역
                VStack(spacing: 12) {
                    /* 이메일 로그인 숨김
                    emailLoginButton
                    */
                    
                    appleButton
                        .disabled(isLoading)
                    /* 카카오도 숨김
                    kakaoButton
                        .disabled(isLoading)
                     */
                }
                .frame(maxWidth: buttonMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            
            if isLoading {
                Color.black.opacity(0.1).ignoresSafeArea()
                ProgressView()
            }
        }
        // ✅ 3) 버튼 클릭 시 EmailLoginView를 풀스크린으로 띄움
        .fullScreenCover(isPresented: $showEmailLogin) {
            EmailLoginView()
        }
        .alert("안내", isPresented: $showAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Email Login Button (New!)
    private var emailLoginButton: some View {
        Button {
            showEmailLogin = true
        } label: {
            Text("이메일로 로그인")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                // Assets에 등록된 브랜드 컬러를 쓰거나, 없으면 Color.brown 등으로 지정
                .background(Color.brandPrimary)
                .cornerRadius(12)
        }
    }

    // MARK: - Apple Button
    private var appleButton: some View {
        AppleSignInButton(
            type: .continue,
            style: .black,
            cornerRadius: 12
        ) {
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
            print("[Login] Apple Sign In error:", error)
            alertMessage = "애플 로그인에 실패했어요."
            showAlert = false
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
                    print("[Login] Kakao error:", error)
                    alertMessage = "카카오 로그인에 실패했어요."
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
