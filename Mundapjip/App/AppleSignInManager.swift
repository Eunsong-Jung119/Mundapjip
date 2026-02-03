
import Foundation
import AuthenticationServices
import CryptoKit

@MainActor
final class AppleSignInManager: NSObject {

    struct Token {
        let idToken: String
        let nonce: String
    }

    private var continuation: CheckedContinuation<Token, Error>?
    private var currentNonce: String?

    // MARK: - Public
    func signIn() async throws -> Token {
        // 1) nonce 만들기
        let nonce = randomNonceString()
        currentNonce = nonce

        // 2) 요청 구성
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [] // 이름/이메일 필요없으면 비워도 됨
        request.nonce = sha256(nonce)

        // 3) 컨트롤러 실행
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()

        // 4) async로 결과 기다리기
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
        }
    }
}

// MARK: - Delegate
extension AppleSignInManager: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let nonce = currentNonce
        else {
            continuation?.resume(throwing: NSError(domain: "AppleSignIn", code: -1))
            continuation = nil
            return
        }

        guard let identityToken = credential.identityToken,
              let idToken = String(data: identityToken, encoding: .utf8)
        else {
            continuation?.resume(throwing: NSError(domain: "AppleSignIn", code: -2))
            continuation = nil
            return
        }

        continuation?.resume(returning: .init(idToken: idToken, nonce: nonce))
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// MARK: - Presentation
extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // 활성 윈도우 찾아서 anchor로
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow } ?? UIWindow()
        return window
    }
}

// MARK: - Helpers
private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.map { String(format: "%02x", $0) }.joined()
}

private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        var randoms = [UInt8](repeating: 0, count: 16)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        if errorCode != errSecSuccess {
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

