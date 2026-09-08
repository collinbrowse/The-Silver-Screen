//
//  MovieDetailHostingController.swift
//  URBNFlicks
//
//  UIKit navigation bridge: SwiftUI toolbar items do not reliably appear on a
//  plain UIHostingController pushed onto a UINavigationController, so the
//  favorite control is owned here via navigationItem.
//

import SwiftUI
import UIKit

@MainActor
final class MovieDetailHostingController: UIViewController {
    private let viewModel: MovieDetailViewModel
    private let imageLoader: ImageLoader
    private var hostingController: UIHostingController<MovieDetailView>!
    private var observationTask: Task<Void, Never>?
    private var starHost: UIHostingController<FavoriteStarButton>?

    init(
        movieID: Int,
        movies: MovieRepository,
        favorites: FavoritesRepository,
        imageLoader: ImageLoader
    ) {
        self.viewModel = MovieDetailViewModel(
            movieID: movieID,
            movies: movies,
            favorites: favorites
        )
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observationTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground

        let root = MovieDetailView(
            viewModel: viewModel,
            imageLoader: imageLoader,
            showsToolbarFavorite: false
        )
        let host = UIHostingController(rootView: root)
        hostingController = host
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)

        observationTask = Task { [weak self] in
            guard let self else { return }
            for await state in Observations({ self.viewModel.state }) {
                self.syncFavoriteButton(state: state)
            }
        }
    }

    private func syncFavoriteButton(state: LoadState<MovieDetailContent>) {
        guard case .loaded(let content, _) = state else {
            navigationItem.rightBarButtonItem = nil
            starHost = nil
            return
        }

        let root = FavoriteStarButton(isFavorite: content.isFavorite) { [weak self] in
            Task { await self?.viewModel.toggleFavorite() }
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
