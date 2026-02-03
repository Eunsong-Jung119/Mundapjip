
import SwiftUI

struct ConnectOtherRoleView: View {
    let currentRole: UserRole
    let generateInviteCode: () async throws -> String

    /// ⬅️ 시트 오픈은 여기서 하지 않고, 부모뷰(QuizContentView)가 수행
    let onRequestConnect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ✅ Emoji (64pt) — Pending/Waiting 톤과 통일
            Text("🤝")
                .font(.system(size: 64))
                .padding(.bottom, 16)

            // ✅ Title (20pt)
            Text("가족과 연결이 필요해요")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            // ✅ Description (16pt, secondary)
            Text("함께 문답집을 만들어 나갈 가족을 초대해주세요!")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)

            // ✅ Custom CTA (120x48, radius 12, brandPrimary)
            Button {
                onRequestConnect() // ⭐ sheet 오픈 요청 (로직 유지)
            } label: {
                Text("연결하기")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.brandPrimary)
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

#Preview("ConnectOtherRoleView") {
    ConnectOtherRoleView(
        currentRole: .child,
        generateInviteCode: { "ABCD12" },
        onRequestConnect: { print("open sheet") }
    )
    .background(Color.appBackground)
}

