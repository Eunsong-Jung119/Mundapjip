//
//  AuthGateway.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 10/3/25.
//

import Foundation

enum AuthError: Error { case canceled, failed(String) }

protocol AuthGateway {
    func signInWithGoogle() async throws
    func signOut() async
    var isLoggedIn: Bool { get }
}
