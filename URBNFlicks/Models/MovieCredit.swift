//
//  MovieCredit.swift
//  URBNFlicks
//

import Foundation

struct CastMember: Sendable, Identifiable, Equatable, Hashable {
    /// TMDB credit_id — unique per casting even when the same person plays two roles.
    let id: String
    let personID: Int
    let name: String
    let character: String
    let profilePath: String?
    let order: Int
}

struct CrewMember: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let personID: Int
    let name: String
    let job: String
    let department: String
    let profilePath: String?
}

/// A person shown in a crew carousel after Director / Writing-department filtering and dedupe.
struct CreditedPerson: Sendable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let roles: [String]
    let profilePath: String?

    var rolesLabel: String {
        roles.joined(separator: ", ")
    }
}
