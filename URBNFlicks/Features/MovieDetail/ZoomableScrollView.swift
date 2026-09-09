//
//  ZoomableScrollView.swift
//  URBNFlicks
//

import SwiftUI
import UIKit

/// UIScrollView + UIImageView pinch zoom. Avoids UIHostingController so zoom
/// does not fight SwiftUI layout. When not zoomed, scrolling is disabled so a
/// parent pager can own horizontal swipes.
struct ZoomableScrollView: UIViewRepresentable {
    @Binding var isZoomed: Bool
    let image: UIImage
    var onSingleTap: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(isZoomed: $isZoomed, onSingleTap: onSingleTap)
    }

    func makeUIView(context: Context) -> ZoomScrollView {
        let scrollView = ZoomScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        // At 1x, let the parent fullscreen pager handle swipes and snap.
        scrollView.isScrollEnabled = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.backgroundColor = .clear
        scrollView.addSubview(imageView)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        scrollView.onBoundsChange = { [weak coordinator = context.coordinator] in
            guard let coordinator, !coordinator.isZoomed.wrappedValue else { return }
            coordinator.relayoutImage(force: false)
        }

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSingleTap(_:))
        )
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(singleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: ZoomScrollView, context: Context) {
        context.coordinator.isZoomed = $isZoomed
        context.coordinator.onSingleTap = onSingleTap

        let imageChanged = context.coordinator.imageView?.image !== image
        if imageChanged {
            context.coordinator.imageView?.image = image
            scrollView.setZoomScale(1, animated: false)
            scrollView.isScrollEnabled = false
            context.coordinator.relayoutImage(force: true)
            return
        }

        // Never rebuild layout mid-zoom — that is what causes jitter.
        if isZoomed || scrollView.zoomScale > 1.01 {
            if !isZoomed, scrollView.zoomScale > 1.01 {
                scrollView.setZoomScale(1, animated: false)
                scrollView.isScrollEnabled = false
                context.coordinator.updateInsets()
            }
            return
        }

        context.coordinator.relayoutImage(force: false)
    }

    final class ZoomScrollView: UIScrollView {
        var onBoundsChange: (() -> Void)?
        private var lastBoundsSize: CGSize = .zero

        override func layoutSubviews() {
            super.layoutSubviews()
            let size = bounds.size
            guard abs(size.width - lastBoundsSize.width) > 0.5
                    || abs(size.height - lastBoundsSize.height) > 0.5 else { return }
            lastBoundsSize = size
            onBoundsChange?()
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var isZoomed: Binding<Bool>
        var onSingleTap: (() -> Void)?
        weak var scrollView: ZoomScrollView?
        weak var imageView: UIImageView?
        private var laidOutBounds: CGSize = .zero

        init(isZoomed: Binding<Bool>, onSingleTap: (() -> Void)?) {
            self.isZoomed = isZoomed
            self.onSingleTap = onSingleTap
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let zoomed = scrollView.zoomScale > 1.01
            if isZoomed.wrappedValue != zoomed {
                isZoomed.wrappedValue = zoomed
            }
            scrollView.isScrollEnabled = zoomed
            updateInsets()
        }

        func relayoutImage(force: Bool) {
            guard let scrollView, let imageView, let image = imageView.image else { return }
            let bounds = scrollView.bounds.size
            guard bounds.width > 1, bounds.height > 1 else { return }
            if !force, abs(bounds.width - laidOutBounds.width) < 0.5,
               abs(bounds.height - laidOutBounds.height) < 0.5 {
                return
            }
            laidOutBounds = bounds

            let imageSize = image.size
            guard imageSize.width > 0, imageSize.height > 0 else { return }
            let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
            let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            imageView.frame = CGRect(origin: .zero, size: fitted)
            scrollView.contentSize = fitted
            if scrollView.zoomScale != 1 {
                scrollView.zoomScale = 1
            }
            scrollView.isScrollEnabled = false
            if isZoomed.wrappedValue {
                isZoomed.wrappedValue = false
            }
            updateInsets()
        }

        func updateInsets() {
            guard let scrollView else { return }
            let bounds = scrollView.bounds.size
            let size = scrollView.contentSize
            let offsetX = max((bounds.width - size.width) * 0.5, 0)
            let offsetY = max((bounds.height - size.height) * 0.5, 0)
            scrollView.contentInset = UIEdgeInsets(
                top: offsetY,
                left: offsetX,
                bottom: offsetY,
                right: offsetX
            )
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }
            if scrollView.zoomScale > 1.01 {
                scrollView.setZoomScale(1, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let size = scrollView.bounds.size
                let width = size.width / 2
                let height = size.height / 2
                let rect = CGRect(
                    x: point.x - width / 2,
                    y: point.y - height / 2,
                    width: width,
                    height: height
                )
                scrollView.zoom(to: rect, animated: true)
            }
        }

        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            guard scrollView?.zoomScale ?? 1 <= 1.01 else { return }
            onSingleTap?()
        }
    }
}
