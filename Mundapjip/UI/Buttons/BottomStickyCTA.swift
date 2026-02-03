//
//  BottomStickyCTA.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 8/24/25.
//

import SwiftUI

// BottomStickyCTA.swift (권장 형태)

struct BottomStickyCTA: View {
    let title: String
    let action: () -> Void
    var body: some View {
        PrimaryCTAButton(title: title, action: action)
            .padding(.horizontal, 24)  // 좌우 24
            .padding(.top, 12)         // 위 간격
            .padding(.bottom, 12)      // ⬅️ 과한 값 금지 (12~16 권장)
            .background(Color.clear)   // ⛔️ 배경/머티리얼/ignoresSafeArea 금지
    }
}

#Preview{
    BottomStickyCTA(title: "다음", action: {}   )
}
