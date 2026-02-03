
//
//  QAService.swift
//

import Foundation
import Supabase

final class QAService {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - 제출 (🔥 핵심 엔트리 포인트)

    /// 제출 버튼을 눌렀을 때 호출
    /// - submission 1개 생성
    /// - answers N개를 동일 submission_id로 저장
    func submitAnswers(
        familyId: UUID,
        answers: [Int64: String]
    ) async throws {
        print("🚨 submitAnswers CALLED", Date())
        let session = try await client.auth.session
        let userId = session.user.id

        // 1️⃣ submission 생성
        let submissionId = try await createSubmission(
            familyId: familyId,
            userId: userId
        )

        // 2️⃣ answers 저장 (기존 saveAnswer 재사용)
        for (questionId, text) in answers {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            try await saveAnswer(
                familyId: familyId,
                questionId: questionId,
                text: trimmed,
                isSubmitted: true,
                submissionId: submissionId
            )
        }
    }

    // MARK: - Submission 생성

    /// answers 묶음의 대표 엔티티
    private func createSubmission(
        familyId: UUID,
        userId: UUID
    ) async throws -> UUID {

        struct SubmissionInsert: Encodable {
            let family_id: UUID
            let user_id: UUID
        }

        struct SubmissionRow: Decodable {
            let id: UUID
        }

        let insert = SubmissionInsert(
            family_id: familyId,
            user_id: userId
        )

        let result: SubmissionRow = try await client
            .from("answer_submission")   // ⚠️ 테이블명 실제 것과 일치해야 함
            .insert(insert)
            .select("id")
            .single()
            .execute()
            .value

        return result.id
    }

    // MARK: - Answer 저장

    func saveAnswer(
        familyId: UUID,
        questionId: Int64,
        text: String,
        isSubmitted: Bool,
        submissionId: UUID?
    ) async throws {

        let session = try await client.auth.session
        let userId = session.user.id

        struct AnswerRow: Encodable {
            let family_id: UUID
            let question_id: Int64
            let user_id: UUID
            let body: String          // ✅ 실제 컬럼명
            let is_submitted: Bool
            let submission_id: UUID?
        }

        let row = AnswerRow(
            family_id: familyId,
            question_id: questionId,
            user_id: userId,
            body: text,
            is_submitted: isSubmitted,
            submission_id: submissionId
        )

        try await client
            .from("answers")
            .upsert(
                row,
                onConflict: "family_id,question_id,user_id"
            )
            .execute()
    }

    // MARK: - Load Questions

    func loadQuestions(category: String) async throws -> [Question] {
        let rows: [Question] = try await client
            .from("questions")
            .select()
            .eq("category", value: category)
            .order("id", ascending: true)
            .execute()
            .value

        return rows
    }

    // MARK: - Load My Answers

    func loadMyAnswers(familyId: UUID) async throws -> [Int64: String] {
        let session = try await client.auth.session
        let userId = session.user.id

        struct Row: Decodable {
            let question_id: Int64
            let body: String?
        }

        let rows: [Row] = try await client
            .from("answers")
            .select("question_id, body")
            .eq("family_id", value: familyId)
            .eq("user_id", value: userId)
            .execute()
            .value

        var dict: [Int64: String] = [:]
        for r in rows {
            dict[r.question_id] = r.body ?? ""
        }

        return dict
    }
}

