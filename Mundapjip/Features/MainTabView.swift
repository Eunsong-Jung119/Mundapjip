
import SwiftUI

private enum FamilyServiceError: Error { case missing }

struct MainTabView: View {
    @EnvironmentObject private var session: SessionManager
    @State private var selection: Tab = .home

    enum Tab: Hashable { case home, quiz, profile }

    var body: some View {
        Group {
            switch session.currentUserRole {
            case .parent?, .child?:
                roleTabView()

            case nil:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("역할 정보를 불러오는 중…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("역할 선택으로 이동") {
                        session.route = .selectRole
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
            }
        }
        .onChange(of: session.currentUserRole) { _, _ in
            selection = .home
        }
    }

    // MARK: - TabView

    @ViewBuilder
    private func roleTabView() -> some View {
        TabView(selection: $selection) {

            // HOME TAB
            NavigationStack {
                HomeContentView()
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(Color.appBackground, for: .tabBar)
            .tabItem { Label("홈", systemImage: "house.fill") }
            .tag(Tab.home)

            // QUIZ TAB
            NavigationStack {
                QuizContentView(
                      onGoHome: {
                          selection = .home   // ✅ 여기! "홈으로 가기"의 실제 구현
                      }
                  )
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(Color.appBackground, for: .tabBar)
            .tabItem { Label("답변", systemImage: "envelope") }
            .tag(Tab.quiz)

            // PROFILE TAB
            NavigationStack {
                ProfileView()
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(Color.appBackground, for: .tabBar)
            .tabItem { Label("마이", systemImage: "person.crop.circle") }
            .tag(Tab.profile)
        }
        // ✅ 탭바는 여기서 처리
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.appBackground, for: .tabBar)
    }


}


