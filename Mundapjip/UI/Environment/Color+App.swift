//
//  Color+App.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 12/27/25.
//

//
//  Color+App.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 12/27/25.
//

import SwiftUI

extension Color {

    // MARK: - Hex Initializer
    init(_ hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }

    // MARK: - Background
    static let appBackground = Color(
        red: 249 / 255,
        green: 245 / 255,
        blue: 240 / 255
    )

    static let cardBackground = Color.white

    // MARK: - Brand (🔥 여기서 기준 잡기)
    /// 메인 브랜드 컬러
    static let brandPrimary = Color("#B9A288")

    /// 메인 브랜드 컬러의 약한 버전 (버튼 pressed, 서브 강조용)
    static let brandPrimaryDim = Color("#B9A288").opacity(0.85)

    /// 서브 텍스트 / 캡션용 브랜드 컬러
    static let brandSecondary = Color("#7B6A5C")

    // MARK: - Text
    /// 일반적인 secondary 텍스트 (시스템 컬러)
    static let secondaryText = Color.secondary

    // MARK: - Overlay
    static let dimOverlay = Color.black.opacity(0.8)
}
