//
//  PersonHostingController.swift
//  URBNFlicks
//
//  UIKit navigation bridge: SwiftUI toolbar items do not reliably appear on a
//  plain UIHostingController pushed onto a UINavigationController, so the
//  favorite control is owned here via navigationItem. Fullscreen image
//  presentation is also owned here for the same reason.
//

import SwiftUI
import UIKit

@MainActor
final class PersonHostingController: UIViewController {
    private let viewModel: PersonDetailViewModel
    private let imageLoader: ImageLoader
    private let router: NavigationRouter
    private var hostingController: UIHostingController<PersonDetailView>!
    private var observationTask: Task<Void, Never>?
    private var starHost: UIHostingController<CellFavoriteStar>?
    private var lightboxHost: UIHostingController<FullscreenImageViewer>?
    private var presentedLightboxID: String?

    init(
        personID: Int,
        people: PersonRepository,
        favorites: FavoritesRepository,
        imageLoader: ImageLoader,
        router: NavigationRouter
    ) {
        self.viewModel = PersonDetailViewModel(
            personID: personID,
            people: people,
            favorites: favorites
        )
        self.imageLoader = imageLoader
        self.router = router
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

        let root = PersonDetailView(
            viewModel: viewModel,
            imageLoader: imageLoader,
            router: router,
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
                self.syncLightbox(state: state)
            }
        }
    }

    private func syncFavoriteButton(state: LoadState<PersonDetailContent>) {
        guard case .loaded(let content, _) = state else {
            navigationItem.rightBarButtonItem = nil
            starHost = nil
            return
        }

        let root = CellFavoriteStar(
            name: content.detail.name,
            isFavorite: content.isFavorite
        ) { [weak self] in
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

    private func syncLightbox(state: LoadState<PersonDetailContent>) {
        guard case .loaded(let content, _) = state,
              let fullscreen = content.fullscreenImages else {
            if lightboxHost != nil {
                lightboxHost?.dismiss(animated: true)
                lightboxHost = nil
                presentedLightboxID = nil
            }
            return
        }

        guard presentedLightboxID != fullscreen.id else { return }

        let viewer = FullscreenImageViewer(
            images: fullscreen.images,
            initialID: fullscreen.initialID,
            imageKind: fullscreen.kind,
            imageLoader: imageLoader
        ) { [weak self] in
            self?.viewModel.dismissImages()
        }
        let host = UIHostingController(rootView: viewer)
        host.modalPresentationStyle = .fullScreen
        host.view.backgroundColor = .systemBackground
        presentedLightboxID = fullscreen.id
        lightboxHost = host
        present(host, animated: true)
    }
}
