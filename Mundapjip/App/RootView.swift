

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
                BootLoadingView()

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
        .onChange(of: session.route) { _, newValue in
            print("[route] ->", String(describing: newValue))
        }
    }
}

private struct BootLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("불러오는 중…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
