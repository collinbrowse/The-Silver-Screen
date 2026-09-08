//
//  MovieDetailViewController.swift
//  URBNFlicks
//
//  Created by URBN.
//

import Foundation
import UIKit
import SwiftUI

final class MovieDetailViewController: UIHostingController<MovieDetailView> {
    init(movie: Movie) {
        super.init(rootView: MovieDetailView(movie: movie))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct MovieDetailView: View {
    let movie: Movie

    var body: some View {
        Text(movie.title)
            .navigationTitle(movie.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
