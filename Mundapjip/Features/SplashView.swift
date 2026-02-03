//
//  SplashView.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 7/12/25.
//  Updated on 2025/10/26.
//

import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // 1) 배경
            Image("Splash_Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // 2) 그림 로고
                Image("Mundapjip_Logo_Transparent")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 120)
                    .opacity(opacity)

                // 3) 텍스트 로고 (이미지)
                Image("Mundapjip_Logo_Text")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 44)   // ← 40~48 사이에서 취향 조절
                    .opacity(opacity)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) {
                opacity = 1
            }
        }
    }
}

#Preview {
    SplashView()
}
