
//
//  QuizContentView.swift
//  Mundapjip
//

import SwiftUI
import Supabase

enum QuizState {
    case notAnsweredYet
    case waitingForOther
    case bothAnswered
}

struct QuizContentView: View {
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var familyService: FamilyService

    @State private var showConnectFamilySheet = false
    @State private var showPairToast = false
    @State private var isFamilyStateReady = false   // 🔥 핵심

    private var isParent: Bool { session.currentUserRole == .parent }
    private var otherRoleTitle: String { isParent ? "자녀" : "부모님" }
    let onGoHome: () -> Void

    var body: some View {
        Group {
            if !isFamilyStateReady {
                // ✅ 최초 1회: 상태 준비될 때까지 이 뷰만
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)


            } else {
                mainContent
            }
        }
        .onAppear {
            Task {
                await session.refreshFamilyPairingState()
                await session.refreshAnswerState()
                isFamilyStateReady = true    
            }
        }
    }

    // MARK: - Main Content (이제 번쩍임 없음)
    
    @ViewBuilder
        private var mainContent: some View {
            VStack(spacing: 0) {

                ZStack {

                    if session.currentFamilyId == nil || !session.hasPairedMember {

                        ConnectOtherRoleView(
                            currentRole: session.currentUserRole ?? .child,
                            generateInviteCode: {
                                try await familyService.generateInviteCode()
                            },
                            onRequestConnect: {
                                showConnectFamilySheet = true
                            }
                        )

                    } else {

                        switch currentQuizState {
                        case .notAnsweredYet:
                            PendingMyAnswerView() {
                                onGoHome()
                            }

                        case .waitingForOther:
                            WaitingForOtherView(otherRole: otherRoleTitle)

                        case .bothAnswered:
                            NavigationStack {
                                CompleteAnswerView()
                            }
                        }
                    }

                    if showPairToast {
                        VStack {
                            Spacer()
                            Text("가족 연결이 완료되었어요! 🎉")
                                .font(.callout.bold())
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.dimOverlay)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.bottom, 32)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // ✅ 배경은 여기서만
            .background(Color.appBackground)

            // ✅ 상단 safe area 정리
            .safeAreaInset(edge: .top) {
                Color.appBackground.frame(height: 0)
            }

            // ❌ bottom dummy bar 제거됨

            .sheet(isPresented: $showConnectFamilySheet) {
                connectSheet
            }
        }

    private var connectSheet: some View {
        ConnectFamilySheet(
            otherRole: otherRoleTitle,
            generateInviteCode: {
                try await familyService.generateInviteCode()
            },
            joinWithCode: { code in
                try await familyService.joinFamily(with: code)
            },
            onJoinSuccess: {
                showConnectFamilySheet = false
                Task {
                    await session.refreshFamilyPairingState()   // ✅ 추가: 연결 상태 다시 불러오기
                    await session.refreshAnswerState()          // (선택) 답변 상태도 같이 최신화
                }
                withAnimation { showPairToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showPairToast = false }
                }
            }
        )
    }

    private var currentQuizState: QuizState {
        switch (session.hasAnswered, session.otherHasAnswered) {
        case (false, _): return .notAnsweredYet
        case (true, false): return .waitingForOther
        case (true, true): return .bothAnswered
        }
    }
}


//
// MARK: - 완료된 답변 리스트
//

struct CompleteAnswerView: View {
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var familyService: FamilyService

    var body: some View {
        if let familyId = session.currentFamilyId {
            CompleteAnswerContentView(
                familyId: familyId,
                client: familyService.client
            )
        } else {
            ProgressView("가족 정보 불러오는 중…")
        }
    }
}


struct CompleteAnswerContentView: View {
    @EnvironmentObject private var session: SessionManager

    let familyId: UUID
    let client: SupabaseClient

    @StateObject private var vm = CompleteAnswerViewModel()
    @State private var navigateToPayView = false

    private let captionColor = Color("#7B6A5C")

    var body: some View {
        VStack(spacing: 0) {

            // ✅ TitleSubtitle 재사용
            TitleSubtitle(
                title: "답변 리스트",
                subtitle: "소중한 마음을 담은 편지가 도착했어요!",
                alignment: .leading,
                titleBottomSpacing: 6
            )
            .padding(.top, 16)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            

            if vm.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                        .allowsHitTesting(false)
                    Spacer()
                }
            } else if vm.errorText != nil {
                VStack(spacing: 0) {
                    Spacer()
                    Text("답변을 불러오지 못했어요.\n잠시 후 다시 시도해주세요.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else if vm.items.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    Text("아직 상대방의 제출된 답변이 없어요.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // 결제 유도 배너 (구매 완료 시 숨김)
                        if !session.isPurchased {
                            Button {
                                navigateToPayView = true
                            } label: {
                                PaymentBannerView()
                            }
                            .buttonStyle(.plain)
                            .background(
                                NavigationLink(destination: PayView(), isActive: $navigateToPayView) {
                                    EmptyView()
                                }
                                .hidden()
                            )
                        }
                        
                        ForEach(Array(vm.items.enumerated()), id: \.offset) { index, item in
                            NavigationLink(value: item) {
                                AnswerChevronRow(
                                    numberText: "\(index + 1)번 질문",
                                    title: item.questionBody,
                                    isCompleted: false,
                                    chevronColor: captionColor
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20) // ✅ Home과 통일
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationDestination(for: AnswerListItem.self) { item in
            if let index = vm.items.firstIndex(where: { $0.id == item.id }) {
                AnswerDetailView(items: vm.items, index: index)
            }
        }
        .task(id: taskKey) {
            guard session.currentUserRole?.rawValue != nil else { return }

            do {
                let supaSession = try await client.auth.session
                let myUserId = supaSession.user.id

                await vm.fetchFamilyQuestions(
                    client: client,
                    familyId: familyId,
                    myUserId: myUserId
                )
            } catch {
                print("❌ auth.session error")
            }
        }
    }

    private var taskKey: String {
        "\(familyId.uuidString)-\(session.currentUserRole?.rawValue ?? "nil")"
    }
}

struct AnswerChevronRow: View {
    let numberText: String
    let title: String
    let isCompleted: Bool
    let chevronColor: Color

    var body: some View {
        ZStack {
            QuestionCardRow(
                numberText: numberText,
                title: title,
                isCompleted: isCompleted
            )

            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(chevronColor.opacity(0.9))
            }
            .padding(.trailing, 18)
        }
    }

}

#Preview {
    let client = SupabaseClient(
        supabaseURL: URL(string: "https://placeholder.supabase.co")!,
        supabaseKey: "placeholder-key"
    )
    
    CompleteAnswerContentView(
        familyId: UUID(),
        client: client
    )
    .environmentObject(SessionManager(client: client))
}
