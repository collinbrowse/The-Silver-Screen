//
//  TopMoviesListRepresentable.swift
//  URBNFlicks
//

import SwiftUI
import UIKit

struct TopMoviesListRepresentable: UIViewControllerRepresentable {
    let viewModel: MovieListViewModel
    let imageLoader: ImageLoader
    let favorites: FavoritesRepository

    func makeUIViewController(context: Context) -> UINavigationController {
        let list = MovieListViewController(
            viewModel: viewModel,
            imageLoader: imageLoader,
            favorites: favorites
        )
        return UINavigationController(rootViewController: list)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
