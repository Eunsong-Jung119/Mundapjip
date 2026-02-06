//
//  PushTokenManager.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 12/31/25.
//

import Foundation
import Supabase

@MainActor
final class PushTokenManager {

    static let shared = PushTokenManager()
    private init() {}

    /// BundleConfig에서 Supabase 설정을 읽어 클라이언트 생성
    private let client: SupabaseClient = {
        let bundle = Bundle.main

        // ⏱️ 커스텀 URLSession 설정 - 짧은 타임아웃
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 2.0  // 요청 타임아웃: 2초
        sessionConfig.timeoutIntervalForResource = 5.0 // 전체 리소스 타임아웃: 5초
        sessionConfig.waitsForConnectivity = false
        let customSession = URLSession(configuration: sessionConfig)

        return SupabaseClient(
            supabaseURL: bundle.supabaseURL,
            supabaseKey: bundle.supabaseAnonKey,
            options: SupabaseClientOptions(
                global: .init(session: customSession)
            )
        )
    }()

    private struct PushTokenRow: Encodable {
        let user_id: UUID
        let push_token: String
    }


    /// APNs 토큰을 Supabase에 저장 (무조건 덮어쓰기)
    func save(token: String) async {

        // ✅ 1️⃣ 토큰 길이 강제 검증 (가장 중요)
        guard token.count == 64 else {
            print("❌ Invalid APNs token length:", token.count)
            return
        }

        do {
            let session = try await client.auth.session
            let userId = session.user.id

            let row = PushTokenRow(
                user_id: userId,
                push_token: token
            )

            try await client
                .from("user_push_tokens")   // ✅ 네 테이블명 그대로
                .upsert(row, onConflict: "user_id")
                .execute()

            print("✅ Push token saved (overwrite)")

        } catch {
            print("❌ Failed to save push token:")
        }
    }


}
