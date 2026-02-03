

import SwiftUI

struct SelectRoleView: View {
    @EnvironmentObject private var session: SessionManager
    @State private var selection: UserRole? = nil
    @State private var saving = false
    @State private var showError = false
    @State private var errorMessage = ""

    let onNext: (UserRole) -> Void

    // ✅ CTA 타이틀 분기
    private var ctaTitle: String {
        if saving {
            return "저장 중…"
        }
        if selection == nil {
            return "역할을 선택해주세요"
        }
        return "다음"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            // 헤더
            TitleSubtitle(
                title: "어떻게 참여하시겠어요?",
                subtitle: "가족문답집은 부모와 자녀가 함께 만들어요",
                alignment: .leading,
                titleBottomSpacing: 12
            )
            .padding(.top, 32)

            // 역할 선택
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

            Spacer(minLength: 32)

            // 다음 CTA
            PrimaryCTAButton(title: ctaTitle) {
                guard let role = selection, !saving else { return }
                saving = true
                Task {
                    do {
                        try await session.selectRole(role)
                        onNext(role)
                    } catch {
                        errorMessage = "저장에 실패했어요"
                        showError = true
                    }
                    saving = false
                }
            }
            .disabled(selection == nil || saving)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.appBackground)
        .alert("저장 실패", isPresented: $showError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("잠시 후 다시 시도해주세요.")
        }
    }
}

#Preview("SelectRoleView") {
    SelectRoleView { _ in }
        .background(Color.appBackground)
}

