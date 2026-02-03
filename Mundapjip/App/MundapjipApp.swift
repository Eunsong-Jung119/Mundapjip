
import SwiftUI
import Supabase
import UIKit

@main
struct MundapjipApp: App {
    @StateObject private var session: SessionManager
    @StateObject private var familyService: FamilyService
    private let qaService: QAService

    @State private var isBooting: Bool = true
    @State private var didStartAuthListener: Bool = false  // ✅ 1회 가드

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let supabaseURL = Bundle.main.supabaseURL
        let supabaseAnonKey = Bundle.main.supabaseAnonKey

        let client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey,
            options: SupabaseClientOptions(
                db: .init(schema: "public")
            )
        )

        _session = StateObject(wrappedValue: SessionManager(client: client))
        _familyService = StateObject(wrappedValue: FamilyService(client: client))
        qaService = QAService(client: client)
    }

    var body: some Scene {
        WindowGroup {
            let manager = session

            ZStack {
                if isBooting {
                    SplashView()
                } else {
                    RootView()
                        .environmentObject(manager)
                        .environment(\.qaService, qaService)
                        .environmentObject(familyService)
                        .onOpenURL { url in
                            manager.handleOpenURL(url)
                        }
                }
            }
            .task {
                // ✅ StateObject가 View 트리에 설치된 이후에만 접근
                if !didStartAuthListener {
                    didStartAuthListener = true
                    manager.startAuthListener()
                }

                // 최소 표시 시간 (선택)
                try? await Task.sleep(nanoseconds: 300_000_000)

                await manager.checkAuthState()

                isBooting = false
            }
        }
    }
}

