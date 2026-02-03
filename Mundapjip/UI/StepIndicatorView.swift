//
//  StepIndicatorView.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 7/12/25.
//

import SwiftUI

struct StepIndicatorView: View {
    let totalSteps: Int
    let currentStep: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { idx in
                Circle()
                    .fill(idx == currentStep ? Color.brown : Color.brown.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, 24)
    }
}


#Preview {
    StepIndicatorView(totalSteps: 3, currentStep: 1)
}
