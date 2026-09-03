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
    init(movie: MovieSummary) {
        super.init(rootView: MovieDetailView(movie: movie))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // TODO: Finish this view
}

struct MovieDetailView: View {
    let movie: MovieSummary

    var body: some View {
        Text(movie.title)
    }

    // TODO: Finish this view
}