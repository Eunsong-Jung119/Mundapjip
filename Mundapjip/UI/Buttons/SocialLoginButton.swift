//
//  GoogleLoginButton.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 7/19/25.

//
//  AppleLoginButton.swift
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct AppleLoginButton: View {

    let onCompletion: (ASAuthorizationAppleIDCredential) -> Void
    let onFailure: (Error) -> Void

    var body: some View {
        SignInWithAppleButton(
            .continue,
            onRequest: { request in
                // nonce는 LoginView에서 처리
            },
            onCompletion: { result in
                switch result {
                case .success(let auth):
                    if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                        onCompletion(credential)
                    }
                case .failure(let error):
                    onFailure(error)
                }
            }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 56)
        .clipShape(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}


// MARK: - Nonce Helpers (Apple 권장 패턴)
private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        var randoms = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        if status != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed.")
        }

        randoms.forEach { random in
            if remainingLength == 0 { return }
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }
    return result
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.map { String(format: "%02x", $0) }.joined()
}


// MARK: - Kakao Login Button
struct KakaoLoginButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image("KakaoLoginButton") // Assets.xcassets 에 추가된 전체 버튼 이미지
                .resizable()
                .frame(height: 56)
                .frame(maxWidth: .infinity)
        }
    }
}
