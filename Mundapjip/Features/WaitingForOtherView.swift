
//
//  WaitingForOtherView.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 1/18/26.
//

import SwiftUI
import Supabase

struct WaitingForOtherView: View {
    let otherRole: String

    @EnvironmentObject private var session: SessionManager
    @State private var goToCompleteAnswer = false

    // 콕 찌르기 UI 상태
    @State private var nudging = false
    @State private var toastMessage: String? = nil
    @State private var nudgeCooldownUntil: Date? = nil

    private var canNudge: Bool {
        guard !nudging else { return false }
        guard let until = nudgeCooldownUntil else { return true }
        return Date() >= until
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                // ✅ Emoji (64pt) — Pending과 동일 톤
                Text("⏳")
                    .font(.system(size: 64))
                    .padding(.bottom, 16)

                // ✅ Title (20pt)
                Text("\(otherRole)의 답변을 기다리고 있어요")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                // ✅ Description (16pt)
                Text("둘 다 응답을 완료해야 답변을 확인할 수 있어요.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)

                // ✅ Custom CTA: 콕 찌르기 (120x48, radius 12, brandPrimary)
                Button {
                    Task { await sendNudge() }
                } label: {
                    Text(nudging ? "보내는 중…" : "콕 찌르기")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(canNudge ? Color.brandPrimary : Color.brandPrimaryDim)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canNudge)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)

            // ✅ 아주 간단한 토스트
            if let msg = toastMessage {
                VStack {
                    Spacer()
                    Text("\(otherRole)에게 알림을 보냈어요")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.75))
                        )
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: toastMessage)
            }
        }

        // ✅ 폴링: View 살아있는 동안만 (기존 로직 유지)
        .task(id: session.currentFamilyId) {
            // ✅ familyId 없으면 폴링 돌릴 이유 없음
            guard session.currentFamilyId != nil else { return }

            while !Task.isCancelled {
                if session.hasAnswered {
                    await session.refreshAnswerState()
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }

        // ✅ "상대가 답했는지"만 감시 (기존 로직 유지)
        .onChange(of: session.otherHasAnswered) { otherAnswered in
            if otherAnswered && session.hasAnswered {
                goToCompleteAnswer = true
            }
        }

        // ✅ 완료 화면 이동 (기존 로직 유지)
        .navigationDestination(isPresented: $goToCompleteAnswer) {
            CompleteAnswerView()
        }
    }

    // MARK: - Nudge Push

    @MainActor
    private func sendNudge() async {
        guard let familyId = session.currentFamilyId else {
            showToast("가족 정보를 불러오지 못했어요")
            return
        }

        guard canNudge else {
            showToast("잠시 후 다시 시도해주세요")
            return
        }

        nudging = true
        defer { nudging = false }

        do {
            // 1) 내 userId
            let supaSession = try await session.client.auth.session
            let myUserId = supaSession.user.id

            // 2) 같은 familyId의 다른 userId 찾기 (user_families)
            let otherUserId = try await fetchOtherUserId(
                client: session.client,
                familyId: familyId,
                myUserId: myUserId
            )

            // 3) Edge Function 호출 (title/body 커스텀)
            struct NudgePayload: Encodable {
                let to_user_id: String
                let title: String
                let body: String
            }

            let payload = NudgePayload(
                to_user_id: otherUserId.uuidString,
                title: "👀 콕 찌르기",
                body: "답변 작성 부탁해요!"
            )

            let jsonData = try JSONEncoder().encode(payload)

            _ = try await session.client.functions.invoke(
                "notify_answer_completed",
                options: .init(body: jsonData)
            )

            // 4) UX: 토스트 + 쿨다운(예: 30초)
            showToast("알림을 보냈어요")
            nudgeCooldownUntil = Date().addingTimeInterval(30)

        } catch {
            showToast("알림 전송에 실패했어요")
            print("❌ nudge error")
        }
    }

    private func fetchOtherUserId(
        client: SupabaseClient,
        familyId: UUID,
        myUserId: UUID
    ) async throws -> UUID {
        struct UserFamilyRow: Decodable {
            let user_id: UUID
        }

        let res = try await client
            .from("user_families")
            .select("user_id")
            .eq("family_id", value: familyId.uuidString)
            .execute()

        let rows = try JSONDecoder().decode([UserFamilyRow].self, from: res.data)

        if let other = rows.first(where: { $0.user_id != myUserId }) {
            return other.user_id
        }

        throw NSError(domain: "WaitingForOtherView", code: 404, userInfo: [
            NSLocalizedDescriptionKey: "other user not found"
        ])
    }

    @MainActor
    private func showToast(_ msg: String) {
        toastMessage = msg
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if toastMessage == msg {
                toastMessage = nil
            }
        }
    }
}

#Preview("WaitingForOtherView") {
    let mockClient = SupabaseClient(
        supabaseURL: URL(string: "https://preview.supabase.co")!,
        supabaseKey: "preview-key"
    )

    NavigationStack {
        WaitingForOtherView(otherRole: "부모님")
    }
    .environmentObject(SessionManager(client: mockClient))
    .background(Color.appBackground)
}
