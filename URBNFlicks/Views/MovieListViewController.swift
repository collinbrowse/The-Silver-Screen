//
//  MovieListViewController.swift
//  URBNFlicks
//
//  Created by URBN
//

import UIKit

final class MovieListViewController: UIViewController {

    private let viewModel: MovieListViewModel
    private let tableView = UITableView()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private var movies = [Movie]()
    private var stateTask: Task<Void, Never>?

    init(viewModel: MovieListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        setupNavigation()
        setupTableView()
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
        setupLoadingView()

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
        tableView.dataSource = self
        tableView.delegate = self
    }

    private func setupLoadingView() {
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func render(_ state: LoadState<[Movie]>) {
        switch state {
        case .idle:
            loadingView.stopAnimating()
            tableView.isHidden = true
        case .loading:
            loadingView.startAnimating()
            tableView.isHidden = true
        case .empty:
            loadingView.stopAnimating()
            movies = []
            tableView.isHidden = false
            tableView.reloadData()
        case .loaded(let value, _):
            loadingView.stopAnimating()
            movies = value
            tableView.isHidden = false
            tableView.reloadData()
        case .failed:
            loadingView.stopAnimating()
            movies = []
            tableView.isHidden = false
            tableView.reloadData()
        }
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

extension MovieListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        movies.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: MovieTableViewCell.reuseIdentifier,
            for: indexPath
        ) as? MovieTableViewCell else {
            return UITableViewCell()
        }
        cell.configure(with: movies[indexPath.row])
        return cell
    }
}

extension MovieListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let movie = movies[indexPath.row]
        navigationController?.pushViewController(MovieDetailViewController(movie: movie), animated: true)
    }
}
