//
//  FakeAuth.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 10/3/25.
//

import Foundation

final class FakeAuth: AuthGateway {
    private(set) var isLoggedIn = false
    func signInWithGoogle() async throws { try await Task.sleep(nanoseconds: 300_000_000); isLoggedIn = true }
    func signOut() async { isLoggedIn = false }
}

