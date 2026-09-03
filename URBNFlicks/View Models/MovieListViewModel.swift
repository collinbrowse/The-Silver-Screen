//
//  MovieListViewModel.swift
//  URBNFlicks
//
//  Created by URBN
//

import Foundation

final class MovieListViewModel {
    
    private let controller = MovieController()
    
    init() {}
    
    var moviesUpdatedHandler: (([MovieSummary]) -> Void)?

    func getTopMovies() {
        controller.getTopMovies { [weak self] result in
            let movies = try? result.get()
            self?.moviesUpdatedHandler?(movies ?? [MovieSummary]())
        }
    }
}
