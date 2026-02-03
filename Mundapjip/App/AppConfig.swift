//
//  AppConfig.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 10/3/25.
//

import Foundation

enum AppConfig {
  static var supabaseURL: URL {
    guard let host = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_HOST") as? String else {
      assertionFailure("Missing SUPABASE_HOST"); fatalError()
    }
    var c = URLComponents()
    c.scheme = "https"
    c.host   = host
    guard let url = c.url else {
      assertionFailure("Invalid SUPABASE_HOST: \(host)"); fatalError()
    }
    return url
  }

  static var supabaseAnonKey: String {
    guard let k = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
      assertionFailure("Missing SUPABASE_ANON_KEY"); fatalError()
    }
    return k
  }
}
