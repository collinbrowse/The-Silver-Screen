//
//  FavoritePillHostingView.swift
//  URBNFlicks
//

import SwiftUI
import UIKit

/// Embeds `FavoritePillButton` in UIKit cells without owning a view controller lifecycle.
final class FavoritePillHostingView: UIView {
    private var hostingController: UIHostingController<FavoritePillButton>?
    private var onToggle: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = false
        isAccessibilityElement = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(isFavorite: Bool, onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        let root = FavoritePillButton(isFavorite: isFavorite) { [weak self] in
            self?.onToggle?()
        }

        if let hostingController {
            hostingController.rootView = root
            hostingController.view.invalidateIntrinsicContentSize()
        } else {
            let controller = UIHostingController(rootView: root)
            controller.view.backgroundColor = .clear
            controller.view.clipsToBounds = false
            controller.sizingOptions = .intrinsicContentSize
            controller.safeAreaRegions = []
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(controller.view)
            NSLayoutConstraint.activate([
                controller.view.leadingAnchor.constraint(equalTo: leadingAnchor),
                controller.view.trailingAnchor.constraint(equalTo: trailingAnchor),
                controller.view.topAnchor.constraint(equalTo: topAnchor),
                controller.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            hostingController = controller
        }

        invalidateIntrinsicContentSize()
        setNeedsLayout()
        superview?.setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        guard let hostingController else {
            return CGSize(width: 110, height: 36)
        }
        let size = hostingController.sizeThatFits(in: CGSize(
            width: UIView.layoutFittingExpandedSize.width,
            height: UIView.layoutFittingExpandedSize.height
        ))
        return CGSize(width: ceil(size.width), height: max(ceil(size.height), 36))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}
