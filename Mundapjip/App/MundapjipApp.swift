
import SwiftUI
import Supabase
import UIKit

@main
struct MundapjipApp: App {
    @StateObject private var session: SessionManager
    @StateObject private var familyService: FamilyService
    private let qaService: QAService

    @State private var didStartAuthListener: Bool = false

    init() {
        let supabaseURL = Bundle.main.supabaseURL
        let supabaseAnonKey = Bundle.main.supabaseAnonKey

        let client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey,
            options: SupabaseClientOptions(db: .init(schema: "public"))
        )

        _session = StateObject(wrappedValue: SessionManager(client: client))
        _familyService = StateObject(wrappedValue: FamilyService(client: client))
        qaService = QAService(client: client)
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
                    if !didStartAuthListener {
                        didStartAuthListener = true
                        session.startAuthListener()
                    }
                    // ✅ RootView는 이미 떠있고, 그 안에서 session.route == .splash 로 로딩을 보여주면 됨
                    await session.checkAuthState()
                }
        }
    }
}
