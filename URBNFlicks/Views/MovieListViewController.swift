//
//  MovieListViewController.swift
//  URBNFlicks
//
//  Created by URBN
//

import UIKit

final class MovieListViewController: UIViewController {

    private enum Section: Hashable {
        case main
    }

    private let viewModel: MovieListViewModel
    private let imageLoader: ImageLoader
    private let favorites: FavoritesRepository
    private let router: NavigationRouter

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let emptyLabel = UILabel()
    private let errorView = UIStackView()
    private let errorTitleLabel = UILabel()
    private let errorMessageLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let bannerLabel = UILabel()

    private var dataSource: UITableViewDiffableDataSource<Section, Movie.ID>!
    private var moviesByID: [Movie.ID: Movie] = [:]
    private var favoriteIDs: Set<Movie.ID> = []
    private var stateTask: Task<Void, Never>?
    private var sortButton: UIBarButtonItem!

    init(
        viewModel: MovieListViewModel,
        imageLoader: ImageLoader,
        favorites: FavoritesRepository,
        router: NavigationRouter
    ) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        self.favorites = favorites
        self.router = router
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stateTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupNavigation()
        setupTableView()
        setupOverlayViews()
        configureDataSource()

        stateTask = Task { [weak self] in
            guard let self else { return }
            for await state in Observations({ self.viewModel.state }) {
                self.render(state)
            }
        }

        Task { await viewModel.load() }
        Task { await refreshFavoriteIDs() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await refreshFavoriteIDs(reconfigureVisible: true) }
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "Top Ranked Movies"
        sortButton = UIBarButtonItem(
            title: "Sort",
            menu: makeSortMenu()
        )
        navigationItem.rightBarButtonItem = sortButton
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 192
        tableView.register(MovieTableViewCell.self, forCellReuseIdentifier: MovieTableViewCell.reuseIdentifier)
        tableView.delegate = self
        tableView.prefetchDataSource = self
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl?.addTarget(self, action: #selector(pulledToRefresh), for: .valueChanged)
    }

    private func setupOverlayViews() {
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        view.addSubview(loadingView)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "No movies found."
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

        errorTitleLabel.font = .preferredFont(forTextStyle: .title2)
        errorTitleLabel.textAlignment = .center
        errorTitleLabel.numberOfLines = 0

        errorMessageLabel.font = .preferredFont(forTextStyle: .body)
        errorMessageLabel.textAlignment = .center
        errorMessageLabel.textColor = .secondaryLabel
        errorMessageLabel.numberOfLines = 0

        retryButton.setTitle("Retry", for: .normal)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        errorView.axis = .vertical
        errorView.spacing = 12
        errorView.alignment = .center
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.isHidden = true
        errorView.addArrangedSubview(errorTitleLabel)
        errorView.addArrangedSubview(errorMessageLabel)
        errorView.addArrangedSubview(retryButton)
        view.addSubview(errorView)

        bannerLabel.translatesAutoresizingMaskIntoConstraints = false
        bannerLabel.backgroundColor = .systemRed
        bannerLabel.textColor = .white
        bannerLabel.textAlignment = .center
        bannerLabel.font = .preferredFont(forTextStyle: .footnote)
        bannerLabel.numberOfLines = 0
        bannerLabel.isHidden = true
        bannerLabel.accessibilityTraits = .staticText
        view.addSubview(bannerLabel)

        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            emptyLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            emptyLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            bannerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        ])
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Section, Movie.ID>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, movieID in
            guard let self,
                  let cell = tableView.dequeueReusableCell(
                    withIdentifier: MovieTableViewCell.reuseIdentifier,
                    for: indexPath
                  ) as? MovieTableViewCell,
                  let movie = self.moviesByID[movieID] else {
                return UITableViewCell()
            }
            cell.configure(
                with: movie,
                loader: self.imageLoader,
                isFavorite: self.favoriteIDs.contains(movie.id)
            ) { [weak self] in
                self?.toggleFavorite(movie)
            }
            return cell
        }
    }

    // MARK: - Favorites

    private func refreshFavoriteIDs(reconfigureVisible: Bool = false) async {
        do {
            let records = try await favorites.favorites()
            favoriteIDs = Set(records.filter { $0.kind == .movie }.map(\.id))
            if reconfigureVisible {
                reconfigureVisibleCells()
            }
        } catch {
            // Keep last known favorite state; persistence errors surface on toggle.
        }
    }

    private func toggleFavorite(_ movie: Movie) {
        Task { @MainActor in
            do {
                let isFavorite = try await favorites.toggle(movie: movie)
                if isFavorite {
                    favoriteIDs.insert(movie.id)
                } else {
                    favoriteIDs.remove(movie.id)
                }
                reconfigureVisibleCells(for: movie.id)
                let message = isFavorite ? "Added to Favorites" : "Removed from Favorites"
                UIAccessibility.post(notification: .announcement, argument: message)
            } catch let error as AppError {
                showBanner(error)
            } catch {
                showBanner(.unknown)
            }
        }
    }

    private func reconfigureVisibleCells(for movieID: Movie.ID? = nil) {
        guard let visible = tableView.indexPathsForVisibleRows else { return }
        for indexPath in visible {
            guard let id = dataSource.itemIdentifier(for: indexPath),
                  movieID == nil || movieID == id,
                  let movie = moviesByID[id],
                  let cell = tableView.cellForRow(at: indexPath) as? MovieTableViewCell else {
                continue
            }
            cell.configure(
                with: movie,
                loader: imageLoader,
                isFavorite: favoriteIDs.contains(id)
            ) { [weak self] in
                self?.toggleFavorite(movie)
            }
        }
    }

    // MARK: - Render

    private func render(_ state: LoadState<[Movie]>) {
        sortButton.menu = makeSortMenu()

        switch state {
        case .idle:
            tableView.isHidden = true
            emptyLabel.isHidden = true
            errorView.isHidden = true
            bannerLabel.isHidden = true
            loadingView.stopAnimating()

        case .loading:
            tableView.isHidden = true
            emptyLabel.isHidden = true
            errorView.isHidden = true
            bannerLabel.isHidden = true
            loadingView.startAnimating()

        case .empty:
            loadingView.stopAnimating()
            tableView.isHidden = true
            errorView.isHidden = true
            bannerLabel.isHidden = true
            emptyLabel.isHidden = false
            apply(movies: [])

        case .loaded(let movies, let activity):
            loadingView.stopAnimating()
            tableView.isHidden = false
            emptyLabel.isHidden = true
            errorView.isHidden = true
            apply(movies: movies)

            switch activity {
            case .none:
                bannerLabel.isHidden = true
                tableView.refreshControl?.endRefreshing()
            case .refreshing:
                bannerLabel.isHidden = true
            case .loadingMore:
                bannerLabel.isHidden = true
            case .failed(let error):
                tableView.refreshControl?.endRefreshing()
                showBanner(error)
            }

        case .failed(let error):
            loadingView.stopAnimating()
            tableView.isHidden = true
            emptyLabel.isHidden = true
            bannerLabel.isHidden = true
            errorView.isHidden = false
            errorTitleLabel.text = error.title
            errorMessageLabel.text = error.message
            retryButton.isHidden = !error.isRetryable
            errorView.accessibilityLabel = "\(error.title). \(error.message)"
            UIAccessibility.post(notification: .announcement, argument: errorView.accessibilityLabel)
            apply(movies: [])
        }
    }

    private func apply(movies: [Movie]) {
        moviesByID = Dictionary(uniqueKeysWithValues: movies.map { ($0.id, $0) })
        var snapshot = NSDiffableDataSourceSnapshot<Section, Movie.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(movies.map(\.id), toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func showBanner(_ error: AppError) {
        bannerLabel.text = "\(error.title): \(error.message)"
        bannerLabel.isHidden = false
        bannerLabel.accessibilityLabel = bannerLabel.text
        UIAccessibility.post(notification: .announcement, argument: bannerLabel.text)
    }

    private func makeSortMenu() -> UIMenu {
        let actions = SortOption.allCases.map { option in
            UIAction(
                title: option.title,
                state: viewModel.sortOption == option ? .on : .off
            ) { [weak self] _ in
                self?.viewModel.setSortOption(option)
            }
        }
        return UIMenu(title: "Sort Options", options: .singleSelection, children: actions)
    }

    @objc private func pulledToRefresh() {
        Task { await viewModel.refresh() }
    }

    @objc private func retryTapped() {
        Task { await viewModel.retry() }
    }
}

// MARK: - Delegate

extension MovieListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return }
        router.push(.movieDetail(id: id))
    }

    func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        let count = dataSource.snapshot().numberOfItems
        guard count > 0, indexPath.row >= count - 5 else { return }
        Task { await viewModel.loadMore() }
    }
}

// MARK: - Prefetch

extension MovieListViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { indexPath -> URL? in
            guard let id = dataSource.itemIdentifier(for: indexPath),
                  let movie = moviesByID[id],
                  let path = movie.posterPath else { return nil }
            return ImageLoader.posterURL(
                path: path,
                targetWidthPoints: MovieTableViewCell.posterSize.width,
                scale: traitCollection.displayScale
            )
        }
        Task {
            await imageLoader.prefetch(
                urls: urls,
                targetSize: MovieTableViewCell.posterSize,
                scale: traitCollection.displayScale
            )
        }
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { indexPath -> URL? in
            guard let id = dataSource.itemIdentifier(for: indexPath),
                  let movie = moviesByID[id],
                  let path = movie.posterPath else { return nil }
            return ImageLoader.posterURL(
                path: path,
                targetWidthPoints: MovieTableViewCell.posterSize.width,
                scale: traitCollection.displayScale
            )
        }
        Task { await imageLoader.cancelPrefetch(urls: urls) }
    }
}
