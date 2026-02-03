
//
//  OnboardingView.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 8/23/25.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 1) Emoji 64pt
            Text("💌")
                .font(.system(size: 74))
                .padding(.bottom, 16)

            // 2) Title 20pt / bottom padding 8pt
            Text("소중한 사람과 연결하고\n문답집을 완성해보세요")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            // 2) Description 16pt, secondary
            Text("따뜻한 답변이 당신을 기다리고 있을 거예요.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .background(Color.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            // 3) Bottom PrimaryCTAButton
            PrimaryCTAButton(title: "문답집 시작하기") {
                // 4) 로직 변경 X: 기존 finish 액션 그대로
                onFinish()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

#Preview("OnboardingView") {
    OnboardingView { }
        .background(Color.appBackground)
}

