//
//  SceneDelegate.swift
//  URBNFlicks
//
//  Created by URBN
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)

        do {
            let dependencies = try AppDependencies.live()
            let favoritesListViewModel = FavoritesListViewModel(favorites: dependencies.favorites)
            Task { try? await dependencies.favorites.loadIndex() }
            let root = RootTabView(
                router: dependencies.router,
                movies: dependencies.movies,
                people: dependencies.people,
                favorites: dependencies.favorites,
                favoritesIndex: dependencies.favoritesIndex,
                imageLoader: dependencies.imageLoader,
                favoritesListViewModel: favoritesListViewModel
            )
            window.rootViewController = UIHostingController(rootView: root)
        } catch {
            let message: String
            if let appError = error as? AppError {
                message = "\(appError.title)\n\n\(appError.message)"
            } else {
                message = "The app could not start."
            }
            window.rootViewController = StartupFailureViewController(message: message)
        }

        self.window = window
        window.makeKeyAndVisible()
    }
}

private final class StartupFailureViewController: UIViewController {
    private let message: String

    init(message: String) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
