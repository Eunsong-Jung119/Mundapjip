
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
    private var isDeletingAccount = false
    private var isWarmingUp = false
    private var isCheckingAuth = false

    // ⏱️ 앱 시작 시간 측정 (static이므로 앱 생명주기 동안 유지)
    private static let appLaunchTime = Date()
    




    // MARK: - Route / UI State
    enum Route { case splash, onboarding, login, selectRole, home }
    enum Tab { case home, quiz, profile }
    enum TimeoutError: Error { case timedOut }

    enum FamilyError: Error {
        case unexpectedResponse
    }

    enum AccountError: Error {
        case accountDeleted
    }
    
    private enum AuthCache {
        static let isLoggedIn = "auth.cache.isLoggedIn"
        static let userId = "auth.cache.userId"
        static let role = "auth.cache.role"
        static let updatedAt = "auth.cache.updatedAt"
    }


    @Published var route: Route = .splash {
        didSet {
            // ⏱️ 첫 화면 렌더링 시간 측정
            if oldValue == .splash && route != .splash {
                let launchDuration = Date().timeIntervalSince(Self.appLaunchTime) * 1000
                print("⏱️ [Launch] First screen rendered in \(String(format: "%.0f", launchDuration))ms (route: \(route))")

                // 정상 범위 판단
                if launchDuration < 500 {
                    print("✅ [Launch] Excellent! Launch time is under 500ms")
                } else if launchDuration < 1000 {
                    print("✅ [Launch] Good! Launch time is under 1 second")
                } else if launchDuration < 2000 {
                    print("⚠️ [Launch] Acceptable but could be improved (1-2 seconds)")
                } else {
                    print("❌ [Launch] Slow launch (>2 seconds) - needs optimization")
                }
            }
        }
    }
    @Published var currentTab: Tab = .home
    @Published var rootResetToken = UUID()
    @Published var currentUserId: UUID?
    @Published var hasResolvedRole = false



    // MARK: - User State
    @Published var isLoggedIn: Bool = false
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @Published var currentUserRole: UserRole?
    @AppStorage("hasRequestedPushPermission")
    var hasRequestedPushPermission: Bool = false
    @Published var accountDeletedError: Bool = false
    

    // MARK: - Family State
    @Published var currentFamilyId: UUID?
    @Published var familyPaired: Bool = false   // ← Realtime/RPC로만 갱신
    @Published var hasPairedMember: Bool = false
    @Published var hasAnswered: Bool = false
    @Published var otherHasAnswered: Bool = false

    // MARK: - Init
    init(client: SupabaseClient) {
        self.client = client
        // ✅ 캐시로 즉시 라우트 설정 (네트워크 호출 없음)
        self.route = self.getInitialRouteFromCache()
        print("[init] initial route from cache:", self.route)
    }

    /// 캐시만 사용하여 초기 라우트 결정 (네트워크 호출 없음)
    private func getInitialRouteFromCache() -> Route {
        let cache = loadAuthCache()
        let cacheTTL: TimeInterval = 60 * 60 * 24 // 24시간

        if cache.isLoggedIn,
           let cachedUid = cache.userId,
           let updatedAt = cache.updatedAt,
           Date().timeIntervalSince(updatedAt) < cacheTTL {

            // 캐시된 상태를 published 프로퍼티에 적용
            isLoggedIn = true
            currentUserId = cachedUid
            currentUserRole = cache.role
            // ⭐️ 중요: role이 캐시에 존재할 때만 true
            hasResolvedRole = cache.role != nil

            // 라우트 결정
            if !hasSeenOnboarding { return .onboarding }
            if cache.role == nil { return .selectRole }
            return .home
        }

        // 유효한 캐시가 없으면 로그인/온보딩
        // ⭐️ 중요: hasResolvedRole은 false 유지 (기본값)
        return hasSeenOnboarding ? .login : .onboarding
    }

    // MARK: - Check Auth State

    @MainActor
    func checkAuthState() async {
        let checkStartTime = Date()

        // ✅ 동시 실행만 막기
        if isCheckingAuth {
            print("[auth] checkAuthState blocked (in-flight)")
            return
        }
        isCheckingAuth = true
        defer {
            isCheckingAuth = false
            let checkDuration = Date().timeIntervalSince(checkStartTime) * 1000
            print("⏱️ [Auth] checkAuthState completed in \(String(format: "%.0f", checkDuration))ms")
        }
        
        // ✅ 이미 홈 화면이면 재계산 스킵
        if route == .home {
            print("[auth] already home — skip checkAuthState")
            return
        }

        if hasRunAuthCheck {
            print("[auth] checkAuthState blocked")
            return
        }
        hasRunAuthCheck = true

        // ✅ 0) 캐시 기반 즉시 라우팅 (stale cache 방지)
        let cache = loadAuthCache()
        let cacheTTL: TimeInterval = 60 * 60 * 24 // 24시간

        if cache.isLoggedIn,
           let cachedUid = cache.userId,
           let updatedAt = cache.updatedAt,
           Date().timeIntervalSince(updatedAt) < cacheTTL {

            isLoggedIn = true
            currentUserId = cachedUid
            currentUserRole = cache.role
            decideRouteAfterLogin()
        }

        do {
            // ✅ 1) 세션 조회 (타임아웃)
            let session = try await withTimeout(seconds: 2.0) {
                try await self.client.auth.session
            }

            isLoggedIn = true
            let uid = session.user.id
            currentUserId = uid

            // ⏱️ Push 권한 요청은 나중으로 지연 (메인 스레드 블로킹 방지)
            // requestPushPermissionIfNeeded() - postLoginWarmUp에서 처리

            // ✅ 2) role 조회 + deleted_at 체크 (타임아웃)
            let userIdLower = uid.uuidString.lowercased()
            let role: UserRole? = try await withTimeout(seconds: 2.0) {
                struct RoleRow: Decodable {
                    let role: String?
                    let deleted_at: String?
                }
                let rows: [RoleRow] = try await self.client
                    .from("user_roles")
                    .select("role, deleted_at")
                    .eq("user_id", value: userIdLower)
                    .limit(1)
                    .execute()
                    .value

                // ✅ 탈퇴된 계정 체크
                if let firstRow = rows.first, firstRow.deleted_at != nil {
                    print("❌ Account is deleted (deleted_at exists)")
                    await MainActor.run {
                        self.accountDeletedError = true
                    }
                    throw AccountError.accountDeleted
                }

                if let r = rows.first?.role {
                    return UserRole(rawValue: r)
                }
                return nil
            }

            currentUserRole = role
            hasResolvedRole = true

            // ✅ 3) 성공 캐시 저장
            saveAuthCache(isLoggedIn: true, userId: uid, role: role)

            // ✅ 4) 라우팅
            decideRouteAfterLogin()

            // ✅ 5) 느린 작업 분리
            Task { [weak self] in
                guard let self else { return }
                await self.postLoginWarmUp(userId: uid)
            }

        } catch is TimeoutError {
            print("[auth][timeout] checkAuthState timed out")

            // ✅ 타임아웃 시에도 적절한 라우트 설정
            let cache = loadAuthCache()
            if cache.isLoggedIn, cache.userId != nil, cache.updatedAt != nil {
                print("[auth][timeout] using cached state")
                // 캐시된 라우트 유지
            } else {
                // 캐시 없으면 로그인으로
                clearAuthCache()
                currentUserId = nil
                isLoggedIn = false
                currentUserRole = nil
                hasResolvedRole = false
                route = hasSeenOnboarding ? .login : .onboarding
            }

        } catch is AccountError {
            // ✅ 탈퇴된 계정: 강제 로그아웃
            print("[auth][deleted] Account is deleted - forcing logout")
            accountDeletedError = true
            clearAuthCache()
            currentUserId = nil
            isLoggedIn = false
            currentUserRole = nil
            hasResolvedRole = false
            route = hasSeenOnboarding ? .login : .onboarding

        } catch {
            let msg = String(describing: error)

            if msg.contains("sessionMissing") {
                // ✅ 로그인 안 된 상태: 정상 플로우
                print("[auth][no-session] session missing -> go to login/onboarding")
            } else {
                // ✅ 진짜 에러
                print("[auth][error] checkAuthState failed:", msg)
            }

            // 세션이 없거나 깨졌으니 캐시는 제거하는 게 안전
            clearAuthCache()
            currentUserId = nil
            isLoggedIn = false
            currentUserRole = nil
            hasResolvedRole = false  // ✅ 추가: 에러 시 상태 초기화
            route = hasSeenOnboarding ? .login : .onboarding
        }

    }



    @MainActor
    private func postLoginWarmUp(userId: UUID) async {
        if isWarmingUp { return }
        isWarmingUp = true
        defer { isWarmingUp = false }

        // ✅ 모든 warmup 작업을 병렬로 실행
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.ensureFamilyForUserIfNeeded() }
            group.addTask { await self.initialLoadFamilyId(userId: userId) }
            group.addTask { await self.refreshAnswerState(userId: userId) }
            group.addTask {
                if let token = await PushTokenStore.shared.pendingToken {
                    await PushTokenManager.shared.save(token: token)
                    await MainActor.run {
                        PushTokenStore.shared.pendingToken = nil
                    }
                }
            }
        }

        // ⏱️ 푸시 권한 요청은 5초 후에 (사용자가 앱에 익숙해진 후)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5초
            await MainActor.run {
                self?.requestPushPermissionIfNeeded()
            }
        }
    }
    
    
    @MainActor
    private func refreshRoleAndCache(userId: UUID) async {
        do {
            let userIdLower = userId.uuidString.lowercased()

            struct RoleRow: Decodable {
                let role: String?
                let deleted_at: String?
            }
            let roleRows: [RoleRow] = try await client
                .from("user_roles")
                .select("role, deleted_at")
                .eq("user_id", value: userIdLower)
                .limit(1)
                .execute()
                .value

            // ✅ 탈퇴된 계정 체크
            if let firstRow = roleRows.first, firstRow.deleted_at != nil {
                print("❌ Account is deleted (deleted_at exists) - forcing logout")
                accountDeletedError = true
                await logout()
                return
            }

            let role = roleRows.first?.role.flatMap(UserRole.init(rawValue:))

            currentUserRole = role
            saveAuthCache(isLoggedIn: true, userId: userId, role: role)
            decideRouteAfterLogin()
        } catch {
            // role 조회 실패해도 로그인 자체는 유지 (다음에 checkAuthState에서 재시도)
            print("⚠️ refreshRoleAndCache error: \(error)")
        }
    }




    
    func startAuthListener() async {
        if authListener != nil { return }

        // ✅ 비동기로 변경하여 블로킹 방지
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




    
    func handleOpenURL(_ url: URL) {
        print("[openURL] \(url.absoluteString)")
        client.auth.handle(url)
        // 이후는 startAuthListener가 처리
    }



    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)

        // 새 세션 기준으로 다시 상태 계산
        hasRunAuthCheck = false
        await checkAuthState()
    }
    
    @MainActor
    func signInWithApple(idToken: String, nonce: String) async throws {
        // 1) Supabase 로그인
        _ = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        // 2) 세션을 즉시 읽어서 캐시 반영 (FAST)
        //    실패해도 checkAuthState가 다시 잡아줌
        if let session = try? await client.auth.session {
            let uid = session.user.id
            isLoggedIn = true
            currentUserId = uid

            // role은 아직 모를 수 있으니 nil로 캐시/상태 세팅
            currentUserRole = nil
            saveAuthCache(isLoggedIn: true, userId: uid, role: nil)

            // ✅ 즉시 라우팅 (role 없으면 selectRole로 가게 될 것)
            decideRouteAfterLogin()

            // 3) role은 뒤에서 빠르게 조회해서 업데이트 (SLOW-ish)
            Task { [weak self] in
                guard let self else { return }
                await self.refreshRoleAndCache(userId: uid)
            }
        }

        // 4) 최종 검증/정합성은 checkAuthState가 담당
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
    @MainActor
    func logout() async {
        guard !isLoggingOut else { return } // ✅ 중복 실행 방지
        isLoggingOut = true
        defer { isLoggingOut = false }

        // ✅ 0) 로컬 캐시 먼저 제거 (UI 즉시 로그인 상태로)
        clearAuthCache()

        // 1) 실시간 구독 종료 (중요)
        do {
            try await familyChannel?.unsubscribe()
        } catch {
            print("⚠️ unsubscribe error: \(error)")
        }
        familyChannel = nil

        // 2) Supabase signOut
        do {
            try await client.auth.signOut()
        } catch {
            print("❌ signOut error: \(error)")
            // signOut 실패해도 로컬은 로그아웃 상태로 만드는 게 UX상 낫고,
            // 다음 앱 시작 때 checkAuthState()가 다시 검증해줌
        }

        // 3) 세션/상태 완전 초기화
        hasRunAuthCheck = false

        isLoggedIn = false
        currentUserId = nil
        currentUserRole = nil

        currentFamilyId = nil
        familyPaired = false
        hasPairedMember = false

        hasAnswered = false
        otherHasAnswered = false

        currentTab = .home
        accountDeletedError = false

        // 4) 라우트 전환 + 루트 뷰 강제 재생성
        route = .login
        rootResetToken = UUID()
    }

    // MARK: - Delete Account
    @MainActor
    func deleteAccount() async throws {
        guard !isDeletingAccount else { return } // ✅ 중복 실행 방지
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        // 1) 현재 사용자 ID 가져오기
        let session = try await client.auth.session
        let userId = session.user.id

        // 2) user_roles 테이블의 deleted_at 업데이트 (soft delete)
        struct DeletePayload: Encodable {
            let deleted_at: String
        }

        let payload = DeletePayload(
            deleted_at: ISO8601DateFormatter().string(from: Date())
        )

        _ = try await client
            .from("user_roles")
            .update(payload)
            .eq("user_id", value: userId)
            .execute()

        print("✅ Account marked as deleted (deleted_at updated)")

        // 3) 로컬 캐시 제거
        clearAuthCache()

        // 4) 실시간 구독 종료
        do {
            try await familyChannel?.unsubscribe()
        } catch {
            print("⚠️ unsubscribe error: \(error)")
        }
        familyChannel = nil

        // 5) Supabase signOut
        do {
            try await client.auth.signOut()
        } catch {
            print("❌ signOut error: \(error)")
            // signOut 실패해도 로컬은 로그아웃 상태로 만들기
        }

        // 6) 세션/상태 완전 초기화
        hasRunAuthCheck = false

        isLoggedIn = false
        currentUserId = nil
        currentUserRole = nil

        currentFamilyId = nil
        familyPaired = false
        hasPairedMember = false

        hasAnswered = false
        otherHasAnswered = false

        currentTab = .home

        // 7) 라우트 전환 + 루트 뷰 강제 재생성
        route = .login
        rootResetToken = UUID()

        print("✅ Account deletion completed - user signed out")
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
        saveAuthCache(isLoggedIn: true, userId: session.user.id, role: role)

    }


    // MARK: - Routing
    private func decideRouteAfterLogin() {
        let newRoute: Route

        if !hasSeenOnboarding {
            newRoute = .onboarding
        } else if !hasResolvedRole {
            // ✅ 실제 역할을 알기 전에는 라우트 변경 안 함
            return
        } else if currentUserRole == nil {
            newRoute = .selectRole
        } else {
            newRoute = .home
        }

        // ✅ 라우트가 실제로 변경될 때만 업데이트 (깜빡임 방지)
        if route != newRoute {
            print("[route] transition: \(route) -> \(newRoute)")
            route = newRoute
        }
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
    
    func withTimeout<T>(
        seconds: Double,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError.timedOut
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private func loadAuthCache() -> (isLoggedIn: Bool, userId: UUID?, role: UserRole?, updatedAt: Date?) {
        let d = UserDefaults.standard
        let isLoggedIn = d.bool(forKey: AuthCache.isLoggedIn)
        let userId = d.string(forKey: AuthCache.userId).flatMap(UUID.init(uuidString:))
        let role = d.string(forKey: AuthCache.role).flatMap(UserRole.init(rawValue:))
        let updatedAt = d.object(forKey: AuthCache.updatedAt) as? Date
        return (isLoggedIn, userId, role, updatedAt)
    }

    private func saveAuthCache(isLoggedIn: Bool, userId: UUID?, role: UserRole?) {
        let d = UserDefaults.standard
        d.set(isLoggedIn, forKey: AuthCache.isLoggedIn)
        d.set(userId?.uuidString, forKey: AuthCache.userId)
        d.set(role?.rawValue, forKey: AuthCache.role)
        d.set(Date(), forKey: AuthCache.updatedAt)
    }

    private func clearAuthCache() {
        let d = UserDefaults.standard
        d.removeObject(forKey: AuthCache.isLoggedIn)
        d.removeObject(forKey: AuthCache.userId)
        d.removeObject(forKey: AuthCache.role)
        d.removeObject(forKey: AuthCache.updatedAt)
    }







}

