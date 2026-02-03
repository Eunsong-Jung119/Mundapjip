//
//  Model.swift
//  Mundapjip
//
//  Created by Eunsong Jung on 10/8/25.
//

import Foundation

enum UserRole: String, Codable { case parent = "PARENT", child = "CHILD" }

struct Family: Decodable, Identifiable {
    let id: UUID
    let join_code: String?
}

struct FamilyMember: Decodable {
    let family_id: UUID
    let user_id: UUID
    let role: UserRole
    let status: String
    let joined_at: Date
}

struct Question: Identifiable, Decodable, Hashable {
    let id: Int64
    let body: String
    let category: String?
    let themeKey: String?

    enum CodingKeys: String, CodingKey {
        case id, body, category
        case themeKey = "theme_key"
    }
}


struct Answer: Identifiable, Decodable {
    let id: UUID
    let userId: UUID
    let questionId: Int64
    let content: String
    let createdAt: String?
}

struct AnswerWithQuestion: Identifiable, Decodable {
    let id: UUID
    let body: String
    let createdAt: String?
    let question: QuestionItem

    enum CodingKeys: String, CodingKey {
        case id, body, question
        case createdAt = "created_at"
    }

    struct QuestionItem: Decodable {
        let id: Int64
        let body: String
        let themeKey: String?

        enum CodingKeys: String, CodingKey {
            case id, body
            case themeKey = "theme_key"
        }
    }
}


struct AnswerListItem: Identifiable, Hashable {
    let id: UUID              // answers.id
    let questionId: Int64
    let questionBody: String
    let themeKey: String?
    let createdAt: Date?
    let answerBody: String
}


