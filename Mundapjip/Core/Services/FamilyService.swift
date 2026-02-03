
//
//  FamilyService.swift
//  Mundapjip
//

import Foundation
import Supabase

enum FamilyError: Error {
    case unexpectedResponse
}

@MainActor
final class FamilyService: ObservableObject {

    let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - 초대 코드 생성 (RPC)
    func generateInviteCode() async throws -> String {
        let result: String = try await client
            .rpc("generate_invite_code")   // ✅ params 제거 (DB 함수와 일치)
            .execute()
            .value

        print("📌 generate_invite_code 성공 →", result)
        return result
    }

    // MARK: - 초대 코드로 가족 연결 (attach_family)
    struct AttachFamilyResult: Decodable {
        let family_id: UUID
    }

    /// ✅ family_id만 반환 (Session 건드리지 않음!)
    func joinFamily(with code: String) async throws -> UUID {
        let result: AttachFamilyResult = try await client
            .rpc("attach_family", params: ["p_join_code": code])
            .execute()
            .value

        print("📌 attach_family 성공 → family_id:", result.family_id)
        return result.family_id
    }
}

