//
//  AppDelegate.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 12/31/25.
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        // ⏱️ 백그라운드에서 실행하여 메인 스레드 블로킹 방지
        DispatchQueue.global(qos: .utility).async {
            DispatchQueue.main.async {
                UNUserNotificationCenter.current().delegate = self
            }
        }

        // ⏱️ 원격 알림 등록은 나중으로 지연 (1초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🚀 registerForRemoteNotifications called")
            application.registerForRemoteNotifications()
        }

        return true
    }

    // ✅ APNs 토큰 수신
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        print("📱 token bytes:", deviceToken.count)
        print("📱 token chars:", token.count)

        guard token.count == 64 else {
            print("❌ Invalid APNs token length:", token.count)
            return
        }

        print("📱 APNs token received")

        // ✅ 로그인 전이므로 메모리에만 저장
        PushTokenStore.shared.pendingToken = token
    }


    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for notifications")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

