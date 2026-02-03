//
//  PendingMyAnswerView.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 1/18/26.
//

import SwiftUI

struct PendingMyAnswerView: View {

    // ✅ "답변하기" 누르면 HomeContentView로 보내는 액션 (부모 뷰에서 주입)
    let onGoHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ✅ Emoji (64pt)
            Text("✍️")
                .font(.system(size: 64))
                .padding(.bottom, 16)

            // ✅ Title (20pt)
            Text("답변 작성을 완료해주세요")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)

            // ✅ Description (16pt, secondary)
            Text("응답을 제출해야 상대방의 답변을 확인할 수 있어요")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)

            // ✅ Custom CTA (120x48, radius 12, brand color)
            Button {
                onGoHome()
            } label: {
                Text("답변하기")
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

#Preview("PendingMyAnswerView") {
    PendingMyAnswerView() {
        print("go home")
    }
    .background(Color.appBackground)
}

