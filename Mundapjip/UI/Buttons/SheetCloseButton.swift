//
//  SheetCloseButton.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 10/10/25.
//

import SwiftUI

struct SheetCloseButton: View {
    var onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 8)
    }
}
