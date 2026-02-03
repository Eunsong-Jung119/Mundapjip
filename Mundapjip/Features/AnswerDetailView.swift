
import SwiftUI

struct AnswerDetailView: View {
    let items: [AnswerListItem]
    @State private var index: Int

    @Environment(\.dismiss) private var dismiss

    init(items: [AnswerListItem], index: Int) {
        self.items = items
        self._index = State(initialValue: index)
    }

    private var item: AnswerListItem {
        items[index]
    }

    private var total: Int {
        items.count
    }

    var body: some View {
        ZStack {
            // 1️⃣ 기본 배경
            Color.appBackground
                .ignoresSafeArea()

            // 2️⃣ 테마 이미지
            Group {
                if let key = item.themeKey {
                    Image("theme_\(key)")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                }
            }
            .ignoresSafeArea()
            .opacity(0.35)

            // 3️⃣ 반투명 오버레이
            Color.white
                .opacity(0.4)
                .ignoresSafeArea()

            // 4️⃣ 콘텐츠
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    Spacer().frame(height: 12)

                    // 헤더
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        Spacer()
                    }

                    // 질문
                    Text(item.questionBody)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                    // 날짜
                    Text(item.createdAt?.formatted(date: .numeric, time: .omitted) ?? "")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    // 답변
                    Text(item.answerBody)
                        .font(.body)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        // ✅ QuestionAnswerSheet와 동일한 하단 CTA 위치
        .safeAreaInset(edge: .bottom) {
            ZStack {
                // 👉 다음 / 완료
                PrimaryCTAButton(
                    title: index < total - 1 ? "다음" : "완료"
                ) {
                    if index < total - 1 {
                        index += 1
                    } else {
                        dismiss()
                    }
                }
                .frame(maxWidth: 220)
                .frame(maxWidth: .infinity)

                // 👉 뒤로
                HStack {
                    Button("뒤로") {
                        if index > 0 {
                            index -= 1
                        }
                    }
                    .foregroundStyle(.secondary)
                    .disabled(index == 0)

                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
            // ❗️배경 절대 없음
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
    }
}


private extension AnswerDetailView {
    var themeImage: some View {
        Group {
            if let key = item.themeKey {
                Image("theme_\(key)")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
            }
        }
    }
}

private extension AnswerDetailView {
    var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }
}

private extension AnswerDetailView {
    var questionTitleView: some View {
        Text(item.questionBody)
            .font(.title2.weight(.bold))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
    }
}

private extension AnswerDetailView {
    var answerBodyView: some View {
        Text(item.answerBody)
            .font(.body)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
    }
}

private extension AnswerDetailView {
    var dateView: some View {
        Text(item.createdAt?.formatted(date: .numeric, time: .omitted) ?? "")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

