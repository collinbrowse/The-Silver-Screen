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
    let favoritesIndex: FavoritesIndex
    let router: NavigationRouter
    let makeDestination: @MainActor (Route) -> UIViewController

    func makeCoordinator() -> Coordinator {
        Coordinator(router: router, makeDestination: makeDestination)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let list = MovieListViewController(
            viewModel: viewModel,
            imageLoader: imageLoader,
            favorites: favorites,
            favoritesIndex: favoritesIndex,
            router: router
        )
        let navigationController = UINavigationController(rootViewController: list)
        context.coordinator.attach(to: navigationController)
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        context.coordinator.router = router
        context.coordinator.makeDestination = makeDestination
        context.coordinator.reconcile(with: router.path)
    }

    @MainActor
    final class Coordinator: NSObject, UINavigationControllerDelegate {
        var router: NavigationRouter
        var makeDestination: @MainActor (Route) -> UIViewController

        private weak var navigationController: UINavigationController?
        private var observationTask: Task<Void, Never>?
        private var isReconciling = false

        init(
            router: NavigationRouter,
            makeDestination: @escaping @MainActor (Route) -> UIViewController
        ) {
            self.router = router
            self.makeDestination = makeDestination
        }

        deinit {
            observationTask?.cancel()
        }

        func attach(to navigationController: UINavigationController) {
            self.navigationController = navigationController
            navigationController.delegate = self
            observationTask?.cancel()
            observationTask = Task { [weak self] in
                guard let self else { return }
                for await path in Observations({ self.router.path }) {
                    self.reconcile(with: path)
                }
            }
            reconcile(with: router.path)
        }

        func reconcile(with path: [Route]) {
            guard let navigationController else { return }
            isReconciling = true
            defer { isReconciling = false }

            let desiredCount = path.count + 1
            let animated = navigationController.viewControllers.count > 0
                && navigationController.view.window != nil

            while navigationController.viewControllers.count > desiredCount {
                navigationController.popViewController(animated: animated)
            }

            while navigationController.viewControllers.count < desiredCount {
                let routeIndex = navigationController.viewControllers.count - 1
                guard path.indices.contains(routeIndex) else { break }
                let viewController = makeDestination(path[routeIndex])
                navigationController.pushViewController(viewController, animated: animated)
            }
        }

        func navigationController(
            _ navigationController: UINavigationController,
            didShow viewController: UIViewController,
            animated: Bool
        ) {
            guard !isReconciling else { return }
            let depth = max(0, navigationController.viewControllers.count - 1)
            router.pop(toDepth: depth)
        }
    }
}
