
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
        .alert("탈퇴된 계정입니다", isPresented: $session.accountDeletedError) {
            Button("확인", role: .cancel) {
                session.accountDeletedError = false
            }
        } message: {
            Text("이 계정은 탈퇴 처리되었습니다.\n30일 후 완전히 삭제됩니다.")
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
        } catch let error as AppleSignInManager.SignInError {
            // ✅ 사용자 취소는 알럿 표시 안 함
            switch error {
            case .userCanceled:
                print("[Login] User canceled Apple Sign In")
                return  // 조용히 종료
            case .credentialMissing:
                alertMessage = "인증 정보를 가져오지 못했어요. 다시 시도해주세요."
                showAlert = true
            case .tokenMissing:
                alertMessage = "토큰을 가져오지 못했어요. 다시 시도해주세요."
                showAlert = true
            case .unknownError(let underlyingError):
                print("[Login] Apple Sign In error:", underlyingError)
                alertMessage = "애플 로그인에 실패했어요. 잠시 후 다시 시도해주세요."
                showAlert = true
            }
        } catch {
            // ✅ Supabase 에러나 기타 에러
            print("[Login] Unexpected error:", error)
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
                    // ✅ ASWebAuthenticationSession 취소 에러 체크
                    let nsError = error as NSError
                    
                    // ASWebAuthenticationSessionError.canceledLogin (code 1)
                    if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && nsError.code == 1 {
                        print("[Login] User canceled Kakao Sign In (ASWebAuthenticationSession)")
                        return  // 알럿 표시 안 함
                    }
                    
                    // 추가: 일반적인 취소 패턴도 체크
                    let errorString = String(describing: error).lowercased()
                    if errorString.contains("canceledlogin") || errorString.contains("user cancel") {
                        print("[Login] User canceled Kakao Sign In")
                        return  // 알럿 표시 안 함
                    }

                    // 실제 에러인 경우만 알럿 표시
                    print("[Login] Kakao Sign In error:", error)
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
