//
//  ProcessInfoPreviews.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 10/5/25.
//
// ProcessInfo+Previews.swift

import Foundation

extension ProcessInfo {
    /// SwiftUI Previews에서 실행 중이면 true
    var isRunningInPreviews: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

