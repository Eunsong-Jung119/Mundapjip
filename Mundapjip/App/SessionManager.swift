
//
//  SessionManager.swift
//  Mundapjip
//

import Foundation
import Supabase
import SwiftUI
import UserNotifications

@MainActor
final class SessionManager: ObservableObject {

    // MARK: - Core
    let client: SupabaseClient
    private var hasRunAuthCheck = false
    private var familyChannel: RealtimeChannel?
    private var authListener: Any?
    private var isLoggingOut = false
    private var currentUserId: UUID?
    private var isWarmingUp = false



    // MARK: - Route / UI State
    enum Route { case splash, onboarding, login, selectRole, home }
    enum Tab { case home, quiz, profile }

    enum FamilyError: Error {
        case unexpectedResponse
    }

    @Published var route: Route = .splash
    @Published var currentTab: Tab = .home
    @Published var rootResetToken = UUID()

    // MARK: - User State
    @Published var isLoggedIn: Bool = false
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @Published var currentUserRole: UserRole?
    @AppStorage("hasRequestedPushPermission")
    var hasRequestedPushPermission: Bool = false
    

    // MARK: - Family State
    @Published var currentFamilyId: UUID?
    @Published var familyPaired: Bool = false   // ← Realtime/RPC로만 갱신
    @Published var hasPairedMember: Bool = false
    @Published var hasAnswered: Bool = false
    @Published var otherHasAnswered: Bool = false

    // MARK: - Init
    init(client: SupabaseClient) {
        self.client = client
        // 🚫 여기서는 checkAuthState() 호출 안 함
        // 👉 앱 시작 시에는 MundapjipApp.swift 에서 .task { await session.checkAuthState() } 로 한 번만 실행
    }

    // MARK: - Check Auth State
    @MainActor
    func checkAuthState() async {
        if hasRunAuthCheck {
            print("[auth] checkAuthState blocked")
            return
        }
        hasRunAuthCheck = true

        do {
            // 1) 세션 1회만
            let session = try await client.auth.session
            isLoggedIn = true

            let uid = session.user.id
            currentUserId = uid

            // (선택) 권한 요청은 warmup으로 옮겨도 됨
            requestPushPermissionIfNeeded()

            // 3) role (FAST)
            let userIdLower = uid.uuidString.lowercased()

            struct RoleRow: Decodable { let role: String? }
            let roleRows: [RoleRow] = try await client
                .from("user_roles")
                .select("role")
                .eq("user_id", value: userIdLower)
                .limit(1)
                .execute()
                .value

            if let role = roleRows.first?.role {
                currentUserRole = UserRole(rawValue: role)
            } else {
                currentUserRole = nil
            }

            // 4) 라우팅 먼저 (FAST)
            decideRouteAfterLogin()

            // 5) 느린 작업은 uid 재사용해서 실행 (SLOW)
            Task { [weak self] in
                guard let self else { return }
                await self.postLoginWarmUp(userId: uid)
            }

        } catch {
            currentUserId = nil
            isLoggedIn = false
            route = hasSeenOnboarding ? .login : .onboarding
        }
    }


    @MainActor
    private func postLoginWarmUp(userId: UUID) async {
        if isWarmingUp { return }
        isWarmingUp = true
        defer { isWarmingUp = false }
        
        await ensureFamilyForUserIfNeeded()
        await initialLoadFamilyId(userId: userId)
        await refreshAnswerState(userId: userId)

        if let token = PushTokenStore.shared.pendingToken {
            await PushTokenManager.shared.save(token: token)
            PushTokenStore.shared.pendingToken = nil
        }
    }



    
    func startAuthListener() {
        if authListener != nil { return }

        Task { [weak self] in
            guard let self else { return }

            self.authListener = await self.client.auth.onAuthStateChange { [weak self] _, _ in
                guard let self else { return }

                Task { @MainActor in
                    // ✅ 메인 액터에서만 접근
                    if self.isLoggingOut { return }

                    self.hasRunAuthCheck = false
                    await self.checkAuthState()
                }
            }
        }
    }




    
    func handleOpenURL(_ url: URL) {
        // Supabase가 OAuth redirect URL을 받아 세션을 완성
        print("[openURL] \(url.absoluteString)")
        client.auth.handle(url)

        // 세션 확정 뒤 상태 재계산
        Task { @MainActor in
            self.hasRunAuthCheck = false
            await self.checkAuthState()
        }
    }



    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)

        // 새 세션 기준으로 다시 상태 계산
        hasRunAuthCheck = false
        await checkAuthState()
    }
    
    func signInWithApple(idToken: String, nonce: String) async throws {
        _ = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        // 새 세션 기준으로 다시 상태 계산 (email 로그인과 동일 패턴)
        hasRunAuthCheck = false
        await checkAuthState()
    }
    
    
    func signInWithKakao() async throws {
        guard let redirectURL = URL(string: "mundapjip://login-callback") else {
            return
        }

        try await client.auth.signInWithOAuth(
            provider: .kakao,
            redirectTo: redirectURL,
            scopes: "profile_nickname"
        )
    }


    
    

    // MARK: - Sign Out
    func logout() async {
        isLoggingOut = true
        defer { isLoggingOut = false }
        // 1) 실시간 구독 종료 (중요)
        do {
            try await familyChannel?.unsubscribe()
        } catch {
            print("⚠️ unsubscribe error")
        }
        familyChannel = nil

        // 2) Supabase signOut
        do {
            try await client.auth.signOut()
        } catch {
            print("❌ signOut error")
        }

        // 3) 세션/상태 완전 초기화
        hasRunAuthCheck = false

        isLoggedIn = false
        currentUserRole = nil

        currentFamilyId = nil
        familyPaired = false
        hasPairedMember = false

        hasAnswered = false
        otherHasAnswered = false

        currentTab = .home

        // 4) 라우트 전환 + 루트 뷰 강제 재생성
        route = .login
        rootResetToken = UUID() // 🔥 이게 “터치 먹는 레이어” 해결에 매우 효과적
    }
    // MARK: - Public API (View에서 호출)

    func selectRole(_ role: UserRole) async throws {
        try await upsertRole(role)
        decideRouteAfterLogin()
    }

    func changeRole(_ role: UserRole) async throws {
        try await upsertRole(role)
        // ❌ route 변경 없음
    }


    // MARK: - Save Role, Change Role에서 공통으로 사용하는 upsertRole
    private func upsertRole(_ role: UserRole) async throws {
        let session = try await client.auth.session

        struct Payload: Encodable {
            let user_id: UUID
            let role: String
        }

        let payload = Payload(
            user_id: session.user.id,
            role: role.rawValue
        )

        _ = try await client
            .from("user_roles")
            .upsert(payload, onConflict: "user_id")
            .execute()

        currentUserRole = role
    }


    // MARK: - Routing
    private func decideRouteAfterLogin() {
        if !hasSeenOnboarding {
            route = .onboarding
            return
        }

        if currentUserRole == nil {
            route = .selectRole
            return
        }

        route = .home
    }
    
    // MARK: - Ensure Family if Needed
    private func ensureFamilyForUserIfNeeded() async {
        do {
            // 이미 familyId가 있으면 스킵하고 싶으면 여기서 early return 가능
            // if currentFamilyId != nil { return }

            print("🔧 ensure_family_for_user 호출 시작")

            let _: String = try await client
                .rpc("ensure_family_for_user")
                .execute()
                .value

            print("🔧 ensure_family_for_user 호출 성공")

        } catch {
            print("❌ ensure_family_for_user 실패")
        }
    }


    // MARK: - RPC attach_family
    func attachFamily(joinCode: String) async throws {
        let response = try await client
            .rpc("attach_family", params: ["p_join_code": joinCode])
            .execute()

        guard (200..<300).contains(response.response.statusCode) else {
            throw FamilyError.unexpectedResponse
        }

        print("📌 attach_family 성공 — familyPaired는 Realtime에서 반영")
    }

    // MARK: - Load Family Id from user_families
    private func initialLoadFamilyId(userId: UUID) async {
        do {
            struct Row: Decodable { let family_id: UUID? }

            let rows: [Row] = try await client
                .from("user_families")
                .select("family_id")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value

            guard let fid = rows.first?.family_id else {
                print("[family] no family_id")
                return
            }

            if self.currentFamilyId != fid {
                self.currentFamilyId = fid
                self.familyPaired = true
                subscribeToFamilyRealtime(familyId: fid)
            }
        } catch {
            print("[family] initialLoadFamilyId failed:", error)
        }
    }



    // MARK: - Realtime Subscribe (user_families 테이블)
    func subscribeToFamilyRealtime(familyId: UUID) {
        // ✅ 이미 같은 familyId로 구독 중이면 스킵
        if let channel = familyChannel,
           currentFamilyId == familyId {
            print("⏭️ 동일 familyId → subscribe 스킵:", familyId)
            return
        }
        // 🔴 이미 구독 중이면 해제
        if let channel = familyChannel {
            print("🧹 기존 Realtime unsubscribe")
            channel.unsubscribe()
            familyChannel = nil
        }
        print("📡 Subscribing Realtime for family:", familyId)

        familyChannel = client.realtime.channel("user-families-\(familyId)")

        familyChannel?
            .on(
                "postgres_changes",
                filter: .init(
                    event: "*",
                    schema: "public",
                    table: "user_families"
                )
            ) { [weak self] msg in
                guard let self else { return }

                print("📡 Realtime 이벤트:", msg)

                let payload = msg.payload

                // NEW row
                if let newData = payload["new"] as? [String: Any],
                   let fid = newData["family_id"] as? String {

                    Task { @MainActor in
                        self.currentFamilyId = UUID(uuidString: fid)
                        self.familyPaired = true
                        print("📡 NEW.family_id =", fid)

                        if let uid = self.currentUserId {
                            await self.refreshAnswerState(userId: uid)
                        } else {
                            print("[answer] currentUserId is nil, skip refreshAnswerState")
                        }
                    }
                }

                // OLD row
                if let oldData = payload["old"] as? [String: Any] {
                    print("📡 OLD:", oldData)
                }
            }

        familyChannel?.subscribe()
    }

    // MARK: - Manual RPC Sync (예비용)
    func refreshFamilyPairedStatus() async {
        do {
            // 1️⃣ 현재 로그인 유저 id
            let userId = try await client.auth.session.user.id

            // 2️⃣ 내 family_id 조회 (DB 기준)
            struct Row: Decodable { let family_id: UUID }

            let rows: [Row] = try await client
                .from("user_families")
                .select("family_id")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value

            guard let fid = rows.first?.family_id else {
                // ❗ family 해제된 경우
                if currentFamilyId != nil {
                    print("🚫 family 해제됨")
                    currentFamilyId = nil
                    familyPaired = false
                }
                return
            }

            // 3️⃣ familyId가 바뀐 경우에만 갱신 + subscribe
            if currentFamilyId != fid {
                currentFamilyId = fid
                familyPaired = true

                print("🔄 family_id 변경 감지:", fid)

                subscribeToFamilyRealtime(familyId: fid)
            } else {
                print("⏭️ family_id 동일 → 처리 스킵:", fid)
            }

        } catch {
            print("❌ refreshFamilyPairedStatus 실패:")
        }
    }
    
    

    
    // MARK: - Refresh Answer State (FIXED)
    
    @MainActor
    func refreshAnswerState(userId: UUID) async {
        guard let familyId = currentFamilyId else {
            print("[answer] no familyId")
            return
        }

        do {
            struct SubmissionRow: Decodable { let user_id: UUID }

            let rows: [SubmissionRow] = try await client
                .from("answer_submission")
                .select("user_id")
                .eq("family_id", value: familyId)
                .execute()
                .value

            let submittedUserIds = Set(rows.map { $0.user_id })

            let mySubmitted = submittedUserIds.contains(userId)
            let otherSubmitted = submittedUserIds.contains { $0 != userId }

            self.hasAnswered = mySubmitted
            self.otherHasAnswered = otherSubmitted

            print("[answer] updated my:", mySubmitted, "other:", otherSubmitted)
        } catch {
            print("[answer] refreshAnswerState failed:", error)
        }
    }
    
    @MainActor
    func refreshAnswerState() async {
        guard let uid = currentUserId else {
            print("[answer] no currentUserId")
            return
        }
        await refreshAnswerState(userId: uid)
    }



    
    // MARK: - Check real family pairing (DB 기준)
    func refreshFamilyPairingState() async {
        do {
            // 1️⃣ 현재 로그인 유저 id 가져오기
            let userId = try await client.auth.session.user.id

            // 2️⃣ 내 family_id 다시 조회 (DB 기준)
            struct MyFamilyRow: Decodable {
                let family_id: UUID
            }

            let myRows: [MyFamilyRow] = try await client
                .from("user_families")
                .select("family_id")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value

            guard let familyId = myRows.first?.family_id else {
                hasPairedMember = false
                currentFamilyId = nil
                print("⚠️ no family_id for current user")
                return
            }

            // ✅ 세션에 familyId 갱신
            currentFamilyId = familyId

            // 3️⃣ 같은 family_id를 가진 유저 수 조회
            struct MemberRow: Decodable {
                let user_id: UUID
            }

            let members: [MemberRow] = try await client
                .from("user_families")
                .select("user_id")
                .eq("family_id", value: familyId)
                .execute()
                .value

            hasPairedMember = members.count >= 2

            print("👨‍👩‍👧 family \(familyId) member count:", members.count)

        } catch {
            hasPairedMember = false
            currentFamilyId = nil
            print("❌ refreshFamilyPairingState error")
        }
    }
    
    // MARK: - Ask for Push Permission if needed
    
    func requestPushPermissionIfNeeded() {
        guard !hasRequestedPushPermission else {
            print("🔕 Push permission already requested")
            return
        }

        hasRequestedPushPermission = true

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                print("🔔 Push permission granted:", granted)

                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
    }






}

