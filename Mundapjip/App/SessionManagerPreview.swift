//
//  SessionManagerPreview.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 9/20/25.
//

#if DEBUG
import SwiftUI
import Foundation
import Supabase

// MARK: - 프리뷰 헬퍼 확장
extension SessionManager {

    /// 공용 프리뷰 생성기: 로그인/온보딩/역할 유무를 지정
    static func preview(
        route: Route,
        hasOnboarded: Bool = true,
        role: UserRole? = nil,
        loggedIn: Bool = false
    ) -> SessionManager {
        // ✅ SupabaseClient는 non-optional이므로 더미 인스턴스 사용
        let dummyClient = SupabaseClient(
            supabaseURL: URL(string: "https://dummy.supabase.co")!,
            supabaseKey: "DUMMY_KEY"
        )

        let s = SessionManager(client: dummyClient)
        s.hasSeenOnboarding = hasOnboarded
        s.currentUserRole = role
        s.route = route
        s.isLoggedIn = loggedIn
        return s
    }

    // MARK: - 미리보기 시나리오들

    static var previewSplash: SessionManager {
        preview(route: .splash, hasOnboarded: true, loggedIn: false)
    }

    static var previewOnboarding: SessionManager {
        preview(route: .onboarding, hasOnboarded: false, loggedIn: false)
    }

    static var previewLoggedOut: SessionManager {
        preview(route: .login, hasOnboarded: true, loggedIn: false)
    }

    static var previewSelectRole: SessionManager {
        preview(route: .selectRole, hasOnboarded: true, role: nil, loggedIn: true)
    }

    static var previewLoggedIn: SessionManager {
        preview(route: .home, hasOnboarded: true, role: .parent, loggedIn: true)
    }
}
#endif
