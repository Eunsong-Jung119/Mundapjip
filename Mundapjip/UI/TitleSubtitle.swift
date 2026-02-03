

import SwiftUI

struct TitleSubtitle: View {
    let title: String
    let subtitle: String

    var alignment: TextAlignment = .leading
    var titleBottomSpacing: CGFloat = 12

    var titleFont: Font = .system(size: 24, weight: .bold)
    var subtitleFont: Font = .system(size: 15, weight: .regular)

    private let subtitleColor = Color("#7B6A5C")

    var body: some View {
        VStack(
            alignment: alignment == .leading ? .leading : .center,
            spacing: titleBottomSpacing
        ) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(.primary)
                .multilineTextAlignment(alignment)
                .lineSpacing(4)

            Text(subtitle)
                .font(subtitleFont)
                .foregroundStyle(subtitleColor)
                .multilineTextAlignment(alignment)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(
            maxWidth: .infinity,
            alignment: alignment == .leading ? .leading : .center
        )
    }
}


#Preview {
    TitleSubtitle(
        title: "어떤 역할로 참여하시겠어요?",
        subtitle: "가족문답집은 부모와 자녀가 함께 만들어요."
    )
    .padding(.top, 32)
    .padding(.horizontal, 20)
    .background(Color.appBackground)
}

