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

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let emptyLabel = UILabel()

    private var dataSource: UITableViewDiffableDataSource<Section, Movie.ID>!
    private var moviesByID: [Movie.ID: Movie] = [:]
    private var stateTask: Task<Void, Never>?

    init(viewModel: MovieListViewModel, imageLoader: ImageLoader) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
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
    }

    private func setupNavigation() {
        title = "Top Ranked Movies"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Sort",
            style: .plain,
            target: self,
            action: #selector(sortTapped)
        )
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

        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            emptyLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
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
            cell.configure(with: movie, loader: self.imageLoader)
            return cell
        }
    }

    private func render(_ state: LoadState<[Movie]>) {
        switch state {
        case .idle:
            tableView.isHidden = true
            emptyLabel.isHidden = true
            loadingView.stopAnimating()

        case .loading:
            tableView.isHidden = true
            emptyLabel.isHidden = true
            loadingView.startAnimating()

        case .empty:
            loadingView.stopAnimating()
            tableView.isHidden = true
            emptyLabel.isHidden = false
            apply(movies: [])

        case .loaded(let movies, let activity):
            loadingView.stopAnimating()
            tableView.isHidden = false
            emptyLabel.isHidden = true
            apply(movies: movies)
            switch activity {
            case .none, .failed:
                tableView.refreshControl?.endRefreshing()
            case .refreshing, .loadingMore:
                break
            }

        case .failed:
            loadingView.stopAnimating()
            tableView.isHidden = true
            emptyLabel.isHidden = false
            emptyLabel.text = "Couldn't load movies."
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

    @objc private func pulledToRefresh() {
        Task { await viewModel.refresh() }
    }

    @objc private func sortTapped() {
        let controller = UIAlertController(
            title: "Sort Options",
            message: "Choose your sorting preference",
            preferredStyle: .actionSheet
        )
        controller.addAction(UIAlertAction(title: "Top Ranked ✅", style: .default, handler: nil))
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(controller, animated: true)
    }
}

extension MovieListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath),
              let movie = moviesByID[id] else { return }
        navigationController?.pushViewController(MovieDetailViewController(movie: movie), animated: true)
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
