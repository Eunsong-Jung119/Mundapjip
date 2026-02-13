//
//  PrimaryCTAButton.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 8/24/25.
//

import SwiftUI

struct PrimaryCTAButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(PrimaryCTAButton.Style())
    }
}

extension PrimaryCTAButton {
    static let defaultHeight: CGFloat = 56   // ✅ 합의한 56으로

    struct Style: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled

        private let enabledBackground = Color.brandPrimary
        private let disabledBackground = Color("#E6DED3")

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: PrimaryCTAButton.defaultHeight)   // ✅ 높이 여기서 끝
                .padding(.horizontal, 16)                        // ✅ 좌우만 유지
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isEnabled ? enabledBackground : disabledBackground)
                )
                .shadow(
                    color: .black.opacity(isEnabled ? 0.04 : 0.0),
                    radius: 6,
                    y: 2
                )
                .opacity(isEnabled ? 1.0 : 0.9)
                .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}


