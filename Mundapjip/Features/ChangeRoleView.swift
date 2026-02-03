import SwiftUI

struct ChangeRoleView: View {
    @EnvironmentObject private var session: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selection: UserRole? = nil
    @State private var saving = false
    @State private var showError = false
    @State private var errorMessage = ""

    let onNext: (UserRole) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {

            // MARK: - Main Content
            VStack(alignment: .leading, spacing: 24) {

                // ✅ Header (SelectRoleView와 동일 규격)
                TitleSubtitle(
                    title: "역할을 변경하시겠어요?",
                    subtitle: "기존 역할로 작성된 모든 답변은 볼 수 없게 돼요.",
                    alignment: .leading,
                    titleBottomSpacing: 12
                )
                .padding(.top, 72)

                // ✅ Role Options (SelectRoleView와 동일 spacing 20)
                VStack(spacing: 20) {
                    RoleOptionButton(
                        title: "부모로 참여하기",
                        isSelected: selection == .parent
                    ) { selection = .parent }

                    RoleOptionButton(
                        title: "자녀로 참여하기",
                        isSelected: selection == .child
                    ) { selection = .child }
                }

                Spacer(minLength: 32) // ✅ RoleOptionButton ↔ CTA 간격

                // ✅ CTA (문구 "변경" 유지, 로직 그대로)
                PrimaryCTAButton(title: saving ? "저장 중…" : "변경") {
                    guard let role = selection, !saving else { return }
                    saving = true

                    Task {
                        do {
                            try await session.changeRole(role)
                            onNext(role)   // ✅ ProfileView에서 토스트 처리
                            dismiss()      // ✅ 즉시 복귀
                        } catch {
                            errorMessage = "역할 변경에 실패했어요.\n잠시 후 다시 시도해주세요."
                            showError = true
                        }
                        saving = false
                    }
                }
                .disabled(selection == nil || saving)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20) // ✅ SelectRoleView와 동일: 20
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.appBackground)

            // MARK: - Custom Back Button (유지)
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .tint(.primary)
            }
            .padding(.leading, 16)
            .padding(.top, 12)
        }

        // MARK: - Navigation / Tab 처리 (유지)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)

        // MARK: - Error Alert (유지)
        .alert("저장 실패", isPresented: $showError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("잠시 후 다시 시도해주세요.")
        }
    }
}

#Preview("Standalone Preview") {
    NavigationStack {
        ChangeRoleView { _ in }
    }
    .background(Color.appBackground)
}

