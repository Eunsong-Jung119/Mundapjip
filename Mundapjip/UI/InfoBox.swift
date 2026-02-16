//
//  InfoBox.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 2/16/26.
//


// InfoBox.swift
import SwiftUI

struct InfoBox: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color("#2B211C"))

            Text(subtitle)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.brandSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("#F4EFE9"))
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        InfoBox(
            title: "일회성 결제",
            subtitle: "가족 구성원 중 한 명만, 1회 결제로 \n모든 콘텐츠를 영구소장할 수 있어요"
        )
        InfoBox(
            title: "꼭 확인해주세요!",
            subtitle: "인앱 결제후 환불이 불가능한 상품이에요.\n구매 시, 개인정보처리 방침에 동의하는 것으로 간주돼요"
        )
    }
    .padding(.horizontal, 20)
}
