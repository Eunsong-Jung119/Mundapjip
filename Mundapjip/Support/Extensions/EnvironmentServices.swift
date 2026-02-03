//
//  EnvironmentServices.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 10/8/25.
//

import SwiftUI

private struct QAServiceKey: EnvironmentKey {
    static let defaultValue: QAService? = nil
}

extension EnvironmentValues {
    var qaService: QAService? {
        get { self[QAServiceKey.self] }
        set { self[QAServiceKey.self] = newValue }
    }
}
