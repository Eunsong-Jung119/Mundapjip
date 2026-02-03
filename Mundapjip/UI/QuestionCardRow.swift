
import SwiftUI

struct QuestionCardRow: View {
    let numberText: String
    let title: String               // ✅ 이모지 포함 문자열 그대로
    let isCompleted: Bool

    // MARK: - Design tokens
    private let captionColor = Color("#7B6A5C")
    private let brand = Color("#B9A288")

    private let cardHeight: CGFloat = 80
    private let cornerRadius: CGFloat = 12

    private let contentPadding: CGFloat = 16
    private let numberToTitleGap: CGFloat = 4

    private let textContainerWidth: CGFloat = 269
    private let textContainerHeight: CGFloat = 48

    private let checkSize: CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: numberToTitleGap) {
                    Text(numberText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(captionColor)

                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: textContainerWidth, height: textContainerHeight, alignment: .leading)

                Spacer(minLength: 0)

                if isCompleted {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.15)) // ✅ 원 배경 secondary 느낌
                            .frame(width: checkSize, height: checkSize)

                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(brand)              // ✅ 체크 primary(브랜드)
                    }
                    .frame(width: checkSize, height: checkSize)
                }
            }
            .padding(.horizontal, contentPadding)
            .padding(.vertical, contentPadding)
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
    }
}

#Preview("QuestionCardRow") {
    VStack(spacing: 16) {
        QuestionCardRow(
            numberText: "1번 질문",
            title: "🐯 요즘 엄마/아빠의 관심사는...",
            isCompleted: true
        )
        QuestionCardRow(
            numberText: "2번 질문",
            title: "🤔 노후에는 이런 삶을 상상하고 해...",
            isCompleted: false
        )
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 20)
    .background(Color.appBackground)
}

