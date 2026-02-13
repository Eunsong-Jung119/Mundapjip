
import SwiftUI

struct ConnectFamilySheet: View {

    enum Tab { case invite, join }

    @State private var selectedTab: Tab = .invite
    @State private var inviteCode: String?
    @State private var inputCode: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    // 🔥 초대코드 단 1회 호출 보장
    @State private var hasRequestedInviteCode = false

    // ✅ 복사 토스트
    @State private var showCopiedToast = false

    // ✅ 입력 포커스
    @FocusState private var isInputFocused: Bool

    let otherRole: String
    let generateInviteCode: () async throws -> String

    /// 👉 연결 성공 시 상위뷰로 전달되는 콜백
    let joinWithCode: (String) async throws -> Void
    var onJoinSuccess: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - 탭
            HStack {
                tabButton("초대하기", .invite)
                tabButton("초대코드 입력", .join)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Divider()
                .padding(.bottom, 12)

            Group {
                if selectedTab == .invite {
                    inviteTab
                } else {
                    joinTab
                }
            }
            .animation(.easeInOut, value: selectedTab)

            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
        .background(Color.appBackground)

        // MARK: - 복사 토스트
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Text("초대코드가 복사되었어요!\n가족에게 공유해주세요.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.85))
                    )
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }

        // MARK: - Lifecycle
        .onAppear {
            if selectedTab == .invite && inviteCode == nil {
                Task { await generateCodeOnce() }
            }
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == .invite && inviteCode == nil {
                Task { await generateCodeOnce() }
            }

            if newTab == .join {
                isInputFocused = true
            }
        }
    }

    // MARK: - 탭 버튼
    private func tabButton(_ title: String, _ tab: Tab) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Rectangle()
                .frame(height: 2)
                .foregroundColor(selectedTab == tab ? .brown : .clear)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { selectedTab = tab }
    }

    // MARK: - 초대하기 탭
    private var inviteTab: some View {
        VStack(spacing: 20) {
            Text("초대 코드를 복사해서 \(otherRole)에게 공유해주세요.")
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            if let code = inviteCode {

                HStack(spacing: 10) {
                    ForEach(Array(code.enumerated()), id: \.offset) { _, char in
                        Text(String(char))
                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
                            .frame(width: 40, height: 48)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                }

                Button("초대코드 복사") {
                    let textToCopy =
                    """
                    한 번도 들어본 적 없는 우리가족의 속마음, 궁금하지 않으세요?
                    문답집에서 함께해요

                    초대코드: \(code)
                    """

                    UIPasteboard.general.string = textToCopy

                    withAnimation { showCopiedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation { showCopiedToast = false }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.brown)
                .foregroundColor(.white)
                .cornerRadius(14)

            } else if isLoading {
                ProgressView("초대코드 불러오는 중…")
            } else if errorMessage != nil {
                Text("초대코드를 불러오지 못했어요.")
                    .foregroundColor(.red)

                Button("다시 시도") {
                    Task {
                        hasRequestedInviteCode = false
                        await generateCodeOnce()
                    }
                }
            }
        }
    }

    // MARK: - 초대코드 입력 탭
    private var joinTab: some View {
        VStack(spacing: 20) {
            Text("공유받은 초대코드를 입력하여 연결을 완료해주세요.")
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            // ✅ 실제 입력용 TextField (투명)
            TextField("", text: Binding(
                get: { inputCode },
                set: { newValue in
                    let filtered = newValue
                        .uppercased()
                        .filter { $0.isLetter || $0.isNumber }

                    inputCode = String(filtered.prefix(6))
                }
            ))
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .disableAutocorrection(true)
            .focused($isInputFocused)
            .frame(width: 0, height: 0)
            .opacity(0.01)

            // ✅ 표시용 코드 박스
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    Text(inputCode.count > index ? String(Array(inputCode)[index]) : "")
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .frame(width: 40, height: 48)
                        .background(Color.white)
                        .cornerRadius(8)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = true
            }

            if errorMessage != nil {
                Text("가족 연결에 실패했어요.\n잠시 후 다시 시도해주세요.")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button("연결하기") {
                Task {
                    isLoading = true
                    errorMessage = nil

                    do {
                        try await joinWithCode(inputCode)
                        onJoinSuccess?()
                    } catch {
                        errorMessage = "fail"
                    }

                    isLoading = false
                }
            }
            .disabled(inputCode.count != 6 || isLoading)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.brandPrimary.opacity(inputCode.count == 6 ? 1 : 0.5))
            .foregroundColor(.white)
            .cornerRadius(14)
        }
    }

    // MARK: - Functions
    private func generateCodeOnce() async {
        guard !hasRequestedInviteCode else { return }
        hasRequestedInviteCode = true
        await generateCode()
    }

    private func generateCode() async {
        isLoading = true
        errorMessage = nil
        do {
            inviteCode = try await generateInviteCode()
        } catch {
            errorMessage = "fail"
        }
        isLoading = false
    }
}

