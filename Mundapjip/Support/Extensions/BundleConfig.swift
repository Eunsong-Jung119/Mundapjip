//
//  BundleConfig.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 10/5/25.
//

import Foundation

extension Bundle {
    var supabaseHost: String {
        // ✅ 프리뷰에선 절대 크래시하지 않도록 안전 값 반환
        if ProcessInfo().isRunningInPreviews { return "example.com" }

        guard let host = object(forInfoDictionaryKey: "SUPABASE_HOST") as? String,
              !host.isEmpty else {
            #if DEBUG
            assertionFailure("Missing SUPABASE_HOST in Info.plist")
            #endif
            return "invalid-host"
        }
        return host
    }

    var supabaseURL: URL {
        var c = URLComponents()
        c.scheme = "https"
        c.host   = supabaseHost
        // 프리뷰/폴백
        return c.url ?? URL(string: "https://example.com")!
    }

    var supabaseAnonKey: String {
        // ✅ 프리뷰 안전 값
        if ProcessInfo().isRunningInPreviews { return "test_anon_key" }

        guard let key = object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty else {
            #if DEBUG
            assertionFailure("Missing SUPABASE_ANON_KEY in Info.plist")
            #endif
            return ""
        }
        return key
    }
}
