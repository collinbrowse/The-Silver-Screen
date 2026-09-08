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
    private let movie: Movie
    private let favorites: FavoritesRepository
    private var isFavorite = false
    private var starHost: UIHostingController<FavoriteStarButton>?

    init(movie: Movie, favorites: FavoritesRepository) {
        self.movie = movie
        self.favorites = favorites
        // UIKit path owns the star via navigationItem; hide the SwiftUI toolbar duplicate.
        super.init(rootView: MovieDetailView(movie: movie, favorites: favorites, showsToolbarStar: false))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        updateStarButton()
        Task { await refreshFavoriteState() }
    }

    private func refreshFavoriteState() async {
        do {
            isFavorite = try await favorites.isFavorite(id: movie.id)
            await MainActor.run {
                rootView = MovieDetailView(movie: movie, favorites: favorites, showsToolbarStar: false, loadError: nil)
                updateStarButton()
            }
        } catch let error as AppError {
            await MainActor.run {
                rootView = MovieDetailView(movie: movie, favorites: favorites, showsToolbarStar: false, loadError: error)
            }
        } catch {
            await MainActor.run {
                rootView = MovieDetailView(movie: movie, favorites: favorites, showsToolbarStar: false, loadError: .unknown)
            }
        }
    }

    private func toggleFavorite() {
        Task { @MainActor in
            do {
                isFavorite = try await favorites.toggle(movie: movie)
                rootView = MovieDetailView(movie: movie, favorites: favorites, showsToolbarStar: false, loadError: nil)
                updateStarButton()
                let message = isFavorite ? "Added to Favorites" : "Removed from Favorites"
                UIAccessibility.post(notification: .announcement, argument: message)
            } catch let error as AppError {
                rootView = MovieDetailView(movie: movie, favorites: favorites, showsToolbarStar: false, loadError: error)
            } catch {
                rootView = MovieDetailView(movie: movie, favorites: favorites, showsToolbarStar: false, loadError: .unknown)
            }
        }
    }

    private func updateStarButton() {
        let root = FavoriteStarButton(isFavorite: isFavorite) { [weak self] in
            self?.toggleFavorite()
        }
        if let starHost {
            starHost.rootView = root
        } else {
            let host = UIHostingController(rootView: root)
            host.view.backgroundColor = .clear
            host.view.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
            starHost = host
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: host.view)
        }
    }
}

struct MovieDetailView: View {
    let movie: Movie
    let favorites: FavoritesRepository
    var showsToolbarStar: Bool = true
    var loadError: AppError? = nil

    @State private var isFavorite = false
    @State private var errorMessage: AppError?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(movie.title)
                .font(.title2.bold())
            if let error = errorMessage ?? loadError {
                Text(error.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsToolbarStar {
                ToolbarItem(placement: .topBarTrailing) {
                    FavoriteStarButton(isFavorite: isFavorite) {
                        Task { await toggleFavorite() }
                    }
                }
            }
        }
        .task {
            guard showsToolbarStar else { return }
            await refreshFavoriteState()
        }
    }

    private func refreshFavoriteState() async {
        do {
            isFavorite = try await favorites.isFavorite(id: movie.id)
            errorMessage = nil
        } catch let error as AppError {
            errorMessage = error
        } catch {
            errorMessage = .unknown
        }
    }

    private func toggleFavorite() async {
        do {
            isFavorite = try await favorites.toggle(movie: movie)
            errorMessage = nil
            let message = isFavorite ? "Added to Favorites" : "Removed from Favorites"
            UIAccessibility.post(notification: .announcement, argument: message)
        } catch let error as AppError {
            errorMessage = error
        } catch {
            errorMessage = .unknown
        }
    }
}
