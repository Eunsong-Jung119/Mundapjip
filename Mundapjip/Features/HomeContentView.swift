
import SwiftUI
import PostgREST

struct HomeContentView: View {
    @Environment(\.qaService) private var qaService
    @EnvironmentObject private var session: SessionManager

    // MARK: - Data
    @State private var questions: [Question] = []
    @State private var answers: [Int64: String] = [:]

    // MARK: - Sheet
    @State private var showSheet = false
    @State private var currentIndex = 0

    // MARK: - UI State
    @State private var loading = false
    @State private var submitting = false
    @State private var errorText: String?
    @State private var submitAlert: String?

    private var canSubmit: Bool {
        !questions.isEmpty && questions.allSatisfy { isAnswered($0.id) }
    }

    private var isSubmitAlertPresented: Binding<Bool> {
        Binding(
            get: { submitAlert != nil },
            set: { if !$0 { submitAlert = nil } }
        )
    }

    private let captionColor = Color("#7B6A5C")

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            headerView
            listView
        }
        .safeAreaInset(edge: .bottom) {
            submitBar
        }
        .background(
            Color.appBackground
                .ignoresSafeArea()
        )
        .overlay {
            if loading || submitting {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showSheet) {
            answerSheet
        }
        .alert(submitAlert ?? "", isPresented: isSubmitAlertPresented) {
            Button("확인") {
                submitAlert = nil
                // ✅ 여기서 호출 (사용자가 확인 누른 후 화면 전환)
                Task { await session.refreshAnswerState() }
            }
        }
    }

    // MARK: - UI Blocks

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("질문 리스트")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)

            Text("아래 질문에 대한 답변을 입력하세요.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(captionColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var listView: some View {
        ScrollView {
            if let e = errorText {
                Text(e)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            LazyVStack(spacing: 16) { // ✅ 카드 간격 16
                ForEach(Array(questions.enumerated()), id: \.offset) { index, q in
                    QuestionCardRow(
                        numberText: "\(index + 1)번 질문",
                        title: q.body,                         // ✅ 이모지 유지
                        isCompleted: isAnswered(q.id)           // ✅ 한 글자 이상 입력 로직 그대로
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        currentIndex = index
                        showSheet = true
                    }
                }
            }
            .padding(.horizontal, 20)   // ✅ 카드 폭 353
            .padding(.top, 12)
        }
    }

    private var submitBar: some View {
        VStack(spacing: 0) {
            PrimaryCTAButton(title: canSubmit ? "답변 제출" : "질문의 답변을 완료해 주세요") {
                submit()
            }
            .disabled(!canSubmit || submitting)
            .padding(.horizontal, 20)
            .padding(.vertical, 16) // ✅ bar 높이 88
        }
        .background(Color.appBackground)
    }

    // MARK: - Sheet

    private var answerSheet: some View {
        QuestionAnswerSheet(
            questions: questions,
            index: $currentIndex,
            answers: $answers,
            onClose: { showSheet = false },
            onSaveAllDrafts: { allAnswers in
                await saveAllDraftsToDB(allAnswers)
            },
            onSaveSingleDraft: { questionId, text in
                saveSingleDraftToDB(questionId: questionId, text: text)
            }
        )
        .presentationDetents([.fraction(0.92)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

    private func isAnswered(_ id: Int64) -> Bool {
        let t = answers[id] ?? ""
        return !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        Task { await handleSubmitTapped() }
    }

    // MARK: - Draft Save (Single)

    @MainActor
    private func saveSingleDraftToDB(questionId: Int64, text: String) {
        Task {
            guard
                let qa = qaService,
                let familyId = session.currentFamilyId
            else { return }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            try? await qa.saveAnswer(
                familyId: familyId,
                questionId: questionId,
                text: trimmed,
                isSubmitted: false,
                submissionId: nil
            )
        }
    }

    // MARK: - Draft Save (All)

    @MainActor
    private func saveAllDraftsToDB(_ allAnswers: [Int64: String]) async {
        guard
            let qa = qaService,
            let familyId = session.currentFamilyId
        else { return }

        for (questionId, text) in allAnswers {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            try? await qa.saveAnswer(
                familyId: familyId,
                questionId: questionId,
                text: trimmed,
                isSubmitted: false,
                submissionId: nil
            )
        }
    }

    // MARK: - Submit (Final)

    @MainActor
    private func handleSubmitTapped() async {
        guard !submitting else { return }
        guard let familyId = session.currentFamilyId else { return }
        guard let qaService = qaService else { return }

        submitting = true
        defer { submitting = false }

        do {
            try await qaService.submitAnswers(familyId: familyId, answers: answers)
            submitAlert = "제출이 완료되었습니다."
            // ❌ 기존: await session.refreshAnswerState()
            // ✅ 수정: alert "확인" 버튼 누른 후로 이동
        } catch {
            print("❌ 제출 실패")
            submitAlert = "제출에 실패했어요. 다시 시도해주세요."
        }
    }

    // MARK: - Load

    private func load() async {
        loading = true
        defer { loading = false }

        guard let qa = qaService else { return }
        guard let role = session.currentUserRole else { return }

        do {
            questions = try await qa.loadQuestions(category: role.rawValue)

            // ✅ Force cast 제거 - 안전한 옵셔널 캐스팅으로 변경
            if let fid = session.currentFamilyId {
                if let loadedAnswers = try await qa.loadMyAnswers(familyId: fid) as? [Int64: String] {
                    answers = loadedAnswers
                } else {
                    print("⚠️ 답변 데이터 타입 불일치 - 빈 딕셔너리로 초기화")
                    answers = [:]
                }
            }

            errorText = nil
        } catch {
            print("❌ HomeContentView load error")
            errorText = "데이터를 불러오지 못했어요."
        }
    }
}
