//
//  PushTokenStore.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 1/1/26.
//

@MainActor
final class PushTokenStore {
    static let shared = PushTokenStore()
    private init() {}

    var pendingToken: String?
}
