
import Foundation
import Supabase

@MainActor
final class CompleteAnswerViewModel: ObservableObject {

    @Published private(set) var items: [AnswerListItem] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorText: String?

    private var hasLoadedKey: String?

    // answers + questions만 붙이면 됨 (role은 별도 쿼리로 처리)
    private struct AnswerRow: Decodable {
        let answer_id: UUID
        let body: String
        let created_at: Date?

        let question_id: Int64
        let user_id: UUID

        let questions: QuestionRow

        struct QuestionRow: Decodable {
            let question_body: String
            let theme_key: String?
        }
    }

    private struct UserFamilyRow: Decodable {
        let user_id: UUID
    }

    private struct UserRoleRow: Decodable {
        let user_id: UUID
        let role: String // "PARENT" | "CHILD"
    }

    /// ✅ familyId + myRole 기준으로 “상대(다른 role) userId들” 구하고,
    /// 그 userId들의 answers만 가져온다.
    func fetchFamilyQuestions(
        client: SupabaseClient,
        familyId: UUID,
        myUserId: UUID
    ) async {

        isLoading = true
        defer { isLoading = false }

        do {
            let rows: [AnswerRow] = try await client
                .from("answers")
                .select("""
                    answer_id:id,
                    body,
                    created_at,
                    question_id,
                    user_id,
                    questions (
                        question_body:body,
                        theme_key
                    )
                """)
                .eq("family_id", value: familyId)
                .eq("is_submitted", value: true)
                .neq("user_id", value: myUserId)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            print("🔎 rows count:", rows.count)
            self.items = rows.map { row in
                AnswerListItem(
                    id: row.answer_id,
                    questionId: row.question_id,
                    questionBody: row.questions.question_body,
                    themeKey: row.questions.theme_key,
                    createdAt: row.created_at,
                    answerBody: row.body
                )
            }

            errorText = nil

        } catch {
            errorText = "답변을 불러오지 못했어요."
            print("❌ fetch error")
        }
    }

    func reset() {
        hasLoadedKey = nil
        items = []
        errorText = nil
        isLoading = false
    }
}

