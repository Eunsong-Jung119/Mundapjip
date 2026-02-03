
import SwiftUI

struct QuestionAnswerSheet: View {
    let questions: [Question]
    @Binding var index: Int
    @Binding var answers: [Int64: String]

    var onClose: () -> Void

    var onSaveAllDrafts: (([Int64: String]) async -> Void)? = nil
    var onSaveSingleDraft: ((Int64, String) async -> Void)? = nil

    @FocusState private var focusing: Bool
    @State private var didRequestInitialFocus = false

    private var q: Question { questions[index] }
    private var total: Int { questions.count }
    private var progressText: String { "\(index + 1) / \(total)" }

    private var answerBinding: Binding<String> {
        Binding(
            get: { answers[q.id] ?? "" },
            set: { answers[q.id] = $0 }
        )
    }

    /// 현재 질문만 draft 저장(빈 값은 스킵)
    private func saveCurrentQuestionDraft() {
        let text = (answers[q.id] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { return }

        let currentQuestionId = q.id
        Task {
            await onSaveSingleDraft?(currentQuestionId, text)
        }
    }

    /// ✅ 시트가 올라온 뒤 포커스 1회만 요청
    @MainActor
    private func requestInitialFocusOnce() {
        guard !didRequestInitialFocus else { return }
        didRequestInitialFocus = true

        Task { @MainActor in
            // 시트 애니메이션 종료 이후에 포커스 주기 (0.30~0.45 사이 조절)
            try? await Task.sleep(nanoseconds: 380_000_000)
            focusing = true
        }
    }

    /// ✅ X 버튼 / 스와이프 닫기와 동일한 "저장 + 즉시 닫기"
    private func closeAndSave() {
        onClose()

        let snapshotAnswers = answers
        let currentQuestionId = q.id
        let currentText = (answers[q.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            if !currentText.isEmpty {
                await onSaveSingleDraft?(currentQuestionId, currentText)
            }
            await onSaveAllDrafts?(snapshotAnswers)
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.96, blue: 0.94)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {

                // 헤더
                HStack {
                    Text(progressText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    SheetCloseButton {
                        closeAndSave()
                    }
                }
                .padding(.top, 8)
                .contentShape(Rectangle()) // ✅ 헤더 탭/드래그 반응 개선

                Rectangle()
                    .fill(Color.brown.opacity(0.85))
                    .frame(height: 2)

                // 질문
                Text(q.body)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                // 입력
                ZStack(alignment: .topLeading) {
                    TextEditor(text: answerBinding)
                        .focused($focusing)
                        .frame(minHeight: 160)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )

                    if (answers[q.id] ?? "").isEmpty && !focusing {
                        Text("답변을 입력해 주세요.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 18)
                            .padding(.leading, 18)
                            .allowsHitTesting(false)
                    }
                }

                Spacer(minLength: 0)

                // CTA
                ZStack {
                    PrimaryCTAButton(title: index < total - 1 ? "다음" : "완료") {
                        let currentQuestionId = q.id
                        let currentText = (answers[q.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                        if index < total - 1 {
                            index += 1
                            focusing = true
                        } else {
                            closeAndSave()
                        }

                        Task {
                            if !currentText.isEmpty {
                                await onSaveSingleDraft?(currentQuestionId, currentText)
                            }
                        }
                    }
                    .frame(maxWidth: 220)
                    .frame(maxWidth: .infinity)

                    HStack {
                        Button("뒤로") {
                            if index > 0 {
                                index -= 1
                                focusing = true
                            }
                            saveCurrentQuestionDraft()
                        }
                        .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .onAppear {
            focusing = false              // ✅ 초기엔 인터랙션 우선
            requestInitialFocusOnce()     // ✅ 포커스 1회만, 늦게
        }
        .onDisappear {
            let snapshotAnswers = answers
            Task {
                await onSaveAllDrafts?(snapshotAnswers)
            }
        }
    }
}

