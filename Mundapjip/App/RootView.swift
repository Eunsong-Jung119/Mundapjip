

//
//  RootView.swift
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var familyService: FamilyService
    @Environment(\.scenePhase) private var scenePhase

    @ViewBuilder
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            switch session.route {
            case .splash:
                SplashView()

            case .onboarding:
                OnboardingView {
                    session.hasSeenOnboarding = true
                    session.route = .login
                }

            case .login:
                LoginView()

            case .selectRole:
                SelectRoleView { role in
                    Task {
                        session.currentUserRole = role
                        session.route = .home
                    }
                }

            case .home:
                MainTabView()
            }
        }
        .id(session.rootResetToken)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, session.route == .home {
                Task { await session.refreshAnswerState() }
            }
        }
    }
}

