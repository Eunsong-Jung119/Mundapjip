
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
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    @State private var showUserIdCopiedToast = false

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

        switch role {
        case .parent:
            return "부모님으로 참여중"
        case .child:
            return "자녀로 참여중"
        }
    }
    
    // MARK: - User ID (고객 고유번호)
    private var userIdText: String {
        guard let userId = session.currentUserId?.uuidString else {
            return "알 수 없음"
        }
        let prefix = userId.prefix(6).uppercased()
        return "\(prefix)..."
    }

    // MARK: - Actions
    private func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }

    private func openKakaoChannelChat() {
        openURL(kakaoChannelChatURL)
    }

    private func handleDeleteAccount() {
        Task {
            guard !isDeletingAccount else { return }
            isDeletingAccount = true
            defer { isDeletingAccount = false }

            do {
                try await session.deleteAccount()
            } catch {
                deleteError = "탈퇴 처리 중 오류가 발생했습니다.\n네트워크 연결을 확인하고 다시 시도해주세요."
                print("❌ Delete account error: \(error)")
            }
        }
    }
    
    private func copyUserIdToClipboard() {
        if let userId = session.currentUserId?.uuidString {
            UIPasteboard.general.string = userId
            withAnimation {
                showUserIdCopiedToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation {
                    showUserIdCopiedToast = false
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {

                        headerView

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
                        .buttonStyle(.plain)

                        // MARK: - 정보
                        ProfileSection {
                            ProfileVersionRow(version: appVersion)
                            
                            CustomerIDRow(userId: userIdText) {
                                copyUserIdToClipboard()
                            }

                            
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
                                showDeleteAccountAlert = true
                            }
                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .background(Color.appBackground)

                // MARK: - Loading
                if isDeletingAccount {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.white)

                            Text("탈퇴 처리 중...")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.85))
                        )
                    }
                }

                // MARK: - Toasts
                VStack {
                    Spacer()

                    if showRoleChangedToast {
                        ToastView(message: "역할이 변경되었습니다 🎉")
                    }

                    if showUserIdCopiedToast {
                        ToastView(message: "고객 고유번호가 복사되었습니다")
                    }
                }
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .alert("로그아웃 하시겠어요?", isPresented: $showLogoutAlert) {
                Button("취소", role: .cancel) {}

                Button("로그아웃", role: .destructive) {
                    Task { await session.logout() }
                }
            }
            .alert("정말 탈퇴하시겠어요?", isPresented: $showDeleteAccountAlert) {
                Button("취소", role: .cancel) {}

                Button("탈퇴하기", role: .destructive) {
                    handleDeleteAccount()
                }
            } message: {
                Text("• 계정 정보는 30일 후 완전히 삭제됩니다\n• 가족에게 공유한 답변은 남아있습니다\n• 답변까지 삭제하려면 탈퇴 전 직접 삭제해주세요")
            }
            .alert("탈퇴 실패", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("확인", role: .cancel) {
                    deleteError = nil
                }
                Button("다시 시도") {
                    showDeleteAccountAlert = true
                }
            } message: {
                if let error = deleteError {
                    Text(error)
                }
            }
        }
    }
}

// MARK: - Subviews

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
    var subtitle: String? = nil
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

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

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


struct CustomerIDRow: View {
    let userId: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack {
                Text("고객 고유번호")
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Text(userId)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.85))
            )
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
