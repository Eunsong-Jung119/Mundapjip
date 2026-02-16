//
//  TermsLinkView.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 2/16/26.
//


// TermsLinkView.swift
import SwiftUI

struct TermsLinkView: View {
    private let termsURL = URL(string: "https://stirring-panda-3e5.notion.site/2fb6edc6adb38024a0baf5ba891c7d61?pvs=74")!
    private let privacyURL = URL(string: "https://stirring-panda-3e5.notion.site/2fb6edc6adb380f8bee5f6bfa197e8d1?pvs=74")!

    var body: some View {
        HStack(spacing: 4) {
            Link("이용약관", destination: termsURL)
            Text("및")
                .foregroundStyle(Color.brandSecondary)
            Link("개인정보처리방침", destination: privacyURL)
        }
        .font(.system(size: 12))
        .tint(Color("#767676"))
        .underline()
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    TermsLinkView()
}
