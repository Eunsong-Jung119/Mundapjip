//
//  LockedAnswerView.swift
//  Mundapjip
//

import SwiftUI

struct LockedAnswerView: View {
    @EnvironmentObject private var session: SessionManager
    @State private var navigateToPayView = false
    @State private var isRestoring = false
    @State private var toastMessage: String? = nil

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                Text("\u{1F512}")
                    .font(.system(size: 64))
                    .padding(.bottom, 16)

                Text("열람 기간이 종료되었어요")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                Text("영구소장하면 언제든 다시 볼 수 있어요")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 28)

                // CTA 버튼
                NavigationLink(destination: PayView(), isActive: $navigateToPayView) {
                    EmptyView()
                }
                .hidden()

                Button {
                    navigateToPayView = true
                } label: {
                    Text("영구소장하기")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 200)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.brandPrimary)
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)

                // 복원 버튼
                Button {
                    Task { await restorePurchase() }
                } label: {
                    Text(isRestoring ? "복원 중..." : "이전 구매 복원하기")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.brandSecondary)
                }
                .disabled(isRestoring)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)

            // 토스트
            if let msg = toastMessage {
                VStack {
                    Spacer()
                    Text(msg)
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
    }

    @MainActor
    private func restorePurchase() async {
        isRestoring = true
        defer { isRestoring = false }

        let storeManager = StoreManager()
        await storeManager.restore()

        if storeManager.isPurchased {
            session.isPurchased = true
            await session.updateFamilyPurchaseStatus()
            showToast("구매가 복원되었어요!")
        } else {
            showToast("복원할 구매 내역이 없어요")
        }
    }

    @MainActor
    private func showToast(_ msg: String) {
        toastMessage = msg
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if toastMessage == msg {
                toastMessage = nil
            }
        }
    }
}
