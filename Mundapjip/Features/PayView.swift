//
//  PayView.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 2/16/26.
//

import SwiftUI
import StoreKit

struct PayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var storeManager = StoreManager()

    @State private var isSelected = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack(alignment: .topLeading) {

            // MARK: - Main Content
            VStack(alignment: .leading, spacing: 24) {

                // Header
                TitleSubtitle(
                    title: "문답집을 영구소장 하시겠어요?",
                    subtitle: "무료 버전에서는 7일 동안만 답변을 열람할 수 있어요",
                    alignment: .leading,
                    titleBottomSpacing: 12
                )
                .padding(.top, 72)

                // RoleOptionButton 재사용
                RoleOptionButton(
                    title: storeManager.product?.displayPrice ?? "4,900원",
                    isSelected: isSelected
                ) {
                    isSelected.toggle()
                }

                VStack(spacing: 12) {
                    InfoBox(
                        title: "일회성 결제",
                        subtitle: "가족 구성원 중 한 명만,\n1회 결제로 모든 콘텐츠를 영구소장할 수 있어요"
                    )
                    InfoBox(
                        title: "꼭 확인해주세요!",
                        subtitle: "인앱 결제후 환불이 불가능한 상품이에요.\n구매 시, 개인정보처리 방침에 동의하는 것으로 간주돼요"
                    )
                    TermsLinkView()
                        .padding(.top, 4)
                }

                Spacer(minLength: 32)

                // CTA - 선택해야 활성화
                PrimaryCTAButton(title: purchaseButtonTitle) {
                    Task {
                        await storeManager.purchase()
                        handlePurchaseResult()
                    }
                }
                .disabled(!isSelected || isPurchasing)
                .padding(.bottom, 8)

                // 복원 버튼
                Button {
                    Task {
                        await storeManager.restore()
                        handlePurchaseResult()
                    }
                } label: {
                    Text("이전 구매 복원하기")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.brandSecondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.appBackground)

            // MARK: - Custom Back Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .tint(.primary)
            }
            .padding(.leading, 16)
            .padding(.top, 12)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await storeManager.loadProduct()
        }
        .alert("알림", isPresented: $showErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Helpers

    private var isPurchasing: Bool {
        if case .purchasing = storeManager.purchaseState { return true }
        return false
    }

    private var purchaseButtonTitle: String {
        if case .purchasing = storeManager.purchaseState {
            return "결제 중..."
        }
        return "문답집 구매하기"
    }

    private func handlePurchaseResult() {
        switch storeManager.purchaseState {
        case .purchased:
            session.isPurchased = true
            dismiss()
        case .failed(let message):
            errorMessage = message
            showErrorAlert = true
        default:
            break
        }
    }
}


