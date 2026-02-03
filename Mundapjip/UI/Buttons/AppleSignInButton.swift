//
//  AppleSigninButton.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 2/1/26.
//

import SwiftUI
import AuthenticationServices

struct AppleSignInButton: UIViewRepresentable {
    enum ButtonType {
        case `continue`
        case signIn
        
        var asType: ASAuthorizationAppleIDButton.ButtonType {
            switch self {
            case .continue: return .continue
            case .signIn: return .signIn
            }
        }
    }
    
    let type: ButtonType
    let style: ASAuthorizationAppleIDButton.Style
    let cornerRadius: CGFloat
    let action: () -> Void
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: type.asType, style: style)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        
        // ✅ 강제 라운드
        button.layer.cornerRadius = cornerRadius
        button.clipsToBounds = true
        
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        // ✅ 레이아웃 업데이트 때도 유지
        uiView.layer.cornerRadius = cornerRadius
        uiView.clipsToBounds = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        
        @objc func tapped() { action() }
    }
}
