//
//  Route.swift
//  URBNFlicks
//

import Foundation

enum AppTab: Hashable, Sendable {
    case topMovies
    case favorites
}

enum Route: Hashable, Sendable {
    case movieDetail(id: Int)
    case person(id: Int)
    case personCredits(personID: Int, personName: String, department: CreditDepartment)
}
