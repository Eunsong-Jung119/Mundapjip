
import SwiftUI
import Supabase
import UIKit

@main
struct MundapjipApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var session: SessionManager
    @StateObject private var familyService: FamilyService
    private let qaService: QAService

    @State private var didStartAuthListener: Bool = false

    init() {
        let initStartTime = Date()

        let supabaseURL = Bundle.main.supabaseURL
        let supabaseAnonKey = Bundle.main.supabaseAnonKey

        // ⏱️ 커스텀 URLSession 설정 - 짧은 타임아웃으로 메인 스레드 블로킹 방지
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 2.0  // 요청 타임아웃: 2초
        sessionConfig.timeoutIntervalForResource = 5.0 // 전체 리소스 타임아웃: 5초
        sessionConfig.waitsForConnectivity = false     // 연결 대기 안 함
        let customSession = URLSession(configuration: sessionConfig)

        let client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey,
            options: SupabaseClientOptions(
                db: .init(schema: "public"),
                global: .init(session: customSession)
            )
        )

        _session = StateObject(wrappedValue: SessionManager(client: client))
        _familyService = StateObject(wrappedValue: FamilyService(client: client))
        qaService = QAService(client: client)

        let initDuration = Date().timeIntervalSince(initStartTime) * 1000
        print("⏱️ [Launch] App init completed in \(String(format: "%.0f", initDuration))ms")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environment(\.qaService, qaService)
                .environmentObject(familyService)
                .onOpenURL { url in
                    session.handleOpenURL(url)
                }
                .task {
                    // ✅ UI 렌더링 후에 초기화 작업 시작
                    if !didStartAuthListener {
                        didStartAuthListener = true

                        // ⏱️ 0.1초 지연 후 시작 (첫 화면 렌더링 우선)
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

                        // ✅ 백그라운드에서 리스너 등록 및 인증 체크
                        await withTaskGroup(of: Void.self) { group in
                            group.addTask {
                                await self.session.startAuthListener()
                            }
                            group.addTask {
                                await self.session.checkAuthState()
                            }
                        }
                    }
                }
        }
    }
}
