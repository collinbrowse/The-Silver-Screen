//
//  ViewController.swift
//  URBNFlicks
//
//  Created by URBN
//

import UIKit

class MovieListViewController: UIViewController {
    
    let viewModel: MovieListViewModel
    
    let tableView = UITableView()
    
    var movies = [MovieSummary]()
    
    required init(viewModel: MovieListViewModel) {
        self.viewModel = viewModel
        
        super.init(nibName: nil, bundle: nil)
        
        setupNavigation()
        setupTableView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel.moviesUpdatedHandler = { (movies) in
            self.movies = movies
            self.tableView.reloadData()
        }
        
        viewModel.getTopMovies()
    }
    
    func setupNavigation() {
        title = "Top Ranked Movies"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Sort", style: .plain, target: self, action: #selector(sortTapped))
    }
    
    func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        tableView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        
        tableView.register(MovieTableViewCell.self, forCellReuseIdentifier: "top movie cell")
        
        tableView.dataSource = self
        tableView.delegate = self
    }
}

// MARK: - Sort Actions
extension MovieListViewController {
    
    @objc func sortTapped() {
        let controller = UIAlertController(title: "Sort Options", message: "Choose your sorting preference", preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: "Top Ranked ✅", style: .default, handler: nil))
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(controller, animated: true, completion: nil)
    }
}


// MARK: - Table View DataSource
extension MovieListViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return movies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "top movie cell", for: indexPath) as? MovieTableViewCell else {
            return UITableViewCell()
        }
        
        let currentMovie = movies[indexPath.row]
        cell.configure(with: currentMovie)
        
        return cell
    }
}

// MARK: - Table View Delegate
extension MovieListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //todo implement this one
    }
}
