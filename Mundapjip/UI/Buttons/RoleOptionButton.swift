//
//  RoleOptionButton.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 10/3/25.

import SwiftUI

struct RoleOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 63)
        }
        .buttonStyle(RoleOptionStyle(isSelected: isSelected))
    }
}

struct RoleOptionStyle: ButtonStyle {
    var isSelected: Bool

    private let selectedFill = Color("#EEE9E3")
    private let brand = Color.brandPrimary

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        // ✅ Background
        let background: Color = isSelected ? selectedFill : .white

        // ✅ Stroke
        let strokeColor: Color = isSelected ? brand : Color.black.opacity(0.06)

        // ✅ Text
        // - 기본: 미선택 검정 / 선택 브랜드
        // - 눌림: 브랜드로 살짝 피드백 (미선택일 때만 변화가 느껴짐)
        let textColor: Color = isSelected ? brand : (isPressed ? brand : .black)

        return configuration.label
            .foregroundStyle(textColor)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .shadow(
                // ✅ 거의 없는 수준으로만 (캡쳐처럼 플랫하게)
                color: .black.opacity(0.02),
                radius: 6,
                y: 2
            )
            .scaleEffect(isPressed ? 0.99 : 1)
            .animation(.easeInOut(duration: 0.12), value: isPressed)
    }
}

#Preview {
    VStack(spacing: 12) {
        RoleOptionButton(title: "부모로 참여하기", isSelected: true) { }
        RoleOptionButton(title: "자녀로 참여하기", isSelected: false) { }
    }
    .padding(16)
    .background(Color(red: 0.98, green: 0.96, blue: 0.94))
}



#Preview {
    VStack(spacing: 12) {
        RoleOptionButton(
            title: "부모로 참여하기",
            isSelected: true
        ) { }

        RoleOptionButton(
            title: "자녀로 참여하기",
            isSelected: false
        ) { }
    }
    .padding(16)
    .background(Color(red: 0.98, green: 0.96, blue: 0.94))
}
