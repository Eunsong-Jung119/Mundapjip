//
//  ProfileView.swift
//  Mundapjip
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionManager

    // MARK: - State
    @State private var showRoleChangedToast = false
    @State private var showLogoutAlert = false

    // MARK: - App Version
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "알 수 없음"
    }

    // MARK: - Links
    private let kakaoChannelChatURL = URL(string: "http://pf.kakao.com/_kQMRX/chat")!
    private let termsURL = URL(string: "https://stirring-panda-3e5.notion.site/2fb6edc6adb38024a0baf5ba891c7d61?pvs=74")!
    private let privacyURL = URL(string: "https://stirring-panda-3e5.notion.site/2fb6edc6adb380f8bee5f6bfa197e8d1?pvs=74")!

    // MARK: - Role Display
    private var roleDisplayText: String {
        guard let role = session.currentUserRole else {
            return "역할을 선택해주세요"
        }

        // ⚠️ 네 프로젝트 enum 케이스명에 맞게만 조정!
        switch role {
        case .parent:
            return "부모님으로 참여중"
        case .child:
            return "자녀로 참여중"
        }
    }

    // MARK: - Actions
    private func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }

    private func openKakaoChannelChat() {
        openURL(kakaoChannelChatURL)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {

                        headerView

                        // ✅ 역할 카드: 카드 전체(변경 포함) 탭하면 ChangeRoleView로 이동
                        NavigationLink {
                            ChangeRoleView { _ in
                                withAnimation {
                                    showRoleChangedToast = true
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation {
                                        showRoleChangedToast = false
                                    }
                                }
                            }
                        } label: {
                            RoleCard(roleText: roleDisplayText)
                        }
                        .buttonStyle(.plain)   // ✅ NavigationLink 기본 파란색/하이라이트 제거

                        // MARK: - 정보
                        ProfileSection {
                            ProfileVersionRow(version: appVersion)

                            ProfileRow(title: "이용 약관") {
                                openURL(termsURL)
                            }

                            ProfileRow(title: "개인정보 처리방침") {
                                openURL(privacyURL)
                            }

                            ProfileRow(title: "문의하기") {
                                openKakaoChannelChat()
                            }
                        }

                        // MARK: - 계정
                        ProfileSection {
                            ProfileRow(title: "알림 설정") {
                                openAppNotificationSettings()
                            }

                            ProfileRow(title: "로그아웃") {
                                showLogoutAlert = true
                            }

                            ProfileRow(title: "탈퇴하기", isDestructive: true) {
                                // TODO: 탈퇴 로직 연결
                            }
                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .background(Color.appBackground)

                // MARK: - Toast
                if showRoleChangedToast {
                    VStack {
                        Spacer()

                        Text("역할이 변경되었습니다 🎉")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.85))
                            )
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .alert("로그아웃 하시겠어요?", isPresented: $showLogoutAlert) {
                Button("취소", role: .cancel) {}

                Button("로그아웃", role: .destructive) {
                    Task { await session.logout() }
                }
            }
        }
    }
}

// MARK: - Subviews

/// ✅ 버튼 제거: "변경"은 Text로만 표시 (탭 이벤트를 가로채지 않음)
struct RoleCard: View {
    let roleText: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("역할")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(roleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("변경")
                .font(.subheadline)
                .foregroundStyle(.blue) 
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProfileSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProfileRow: View {
    let title: String
    var isDestructive: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(isDestructive ? .red : .primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .tint(.primary)
            }
            .padding()
        }
    }
}

struct ProfileVersionRow: View {
    let version: String

    var body: some View {
        HStack {
            Text("앱 버전")
                .foregroundStyle(.primary)
            Spacer()
            Text(version)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private var headerView: some View {
    Text("설정")
        .font(.system(size: 24, weight: .bold))
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
        .padding(.bottom, 8)
}

private func openAppNotificationSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
    }
}

#Preview {
    ProfileView()
}

