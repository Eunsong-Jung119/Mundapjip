//
//  Environment+FamilyService.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 11/11/25.
//

import SwiftUI

private struct FamilyServiceKey: EnvironmentKey {
    static var defaultValue: FamilyService? = nil
}

extension EnvironmentValues {
    var familyService: FamilyService {
        get { self[FamilyServiceKey.self]! } // non-optional로 접근
        set { self[FamilyServiceKey.self] = newValue }
    }
}
