//
//  PaymentBannerView.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 2/16/26.
//


// PaymentBannerView.swift
import SwiftUI

// PaymentBannerView.swift - onTap 클로저 제거
struct PaymentBannerView: View {

    var body: some View {
        ZStack(alignment: .leading) {
            Image("PayBanner")
                .resizable()
                .scaledToFill()
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("우리가족 추억 영구보관하기")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color("#3E322B"))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color("#3E322B"))
                    }

                    Text("모든 답변은 7일 동안만 볼 수 있어요!")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.brandSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PaymentBannerView()
}
