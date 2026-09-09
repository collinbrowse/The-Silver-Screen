//
//  FullscreenImageViewer.swift
//  URBNFlicks
//

import SwiftUI
import UIKit

struct FullscreenImageViewer: View {
    let images: [MovieImage]
    let initialID: String
    let imageLoader: ImageLoader
    let onDismiss: () -> Void

    @State private var selection: String
    @State private var isZoomed = false
    @State private var image: UIImage?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.displayScale) private var displayScale

    init(
        images: [MovieImage],
        initialID: String,
        imageLoader: ImageLoader,
        onDismiss: @escaping () -> Void
    ) {
        self.images = images
        self.initialID = initialID
        self.imageLoader = imageLoader
        self.onDismiss = onDismiss
        _selection = State(initialValue: initialID)
    }

    private var currentIndex: Int {
        images.firstIndex(where: { $0.id == selection }) ?? 0
    }

    var body: some View {
        ZStack {
            DesignTheme.canvas.ignoresSafeArea()

            Group {
                if let image {
                    ZoomableScrollView(isZoomed: $isZoomed) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isZoomed else { return }
                onDismiss()
            }

            VStack {
                HStack {
                    Spacer()
                    closeButton
                }
                .padding(.horizontal, DesignSpacing.lg)
                .padding(.top, DesignSpacing.sm)

                Spacer()

                Text("\(currentIndex + 1) of \(images.count)")
                    .font(DesignTypography.metadata)
                    .foregroundStyle(DesignTheme.textPrimary)
                    .padding(.horizontal, DesignSpacing.md)
                    .padding(.vertical, DesignSpacing.sm)
                    .background { chromeBackground }
                    .padding(.bottom, DesignSpacing.lg)
                    .accessibilityLabel("Image \(currentIndex + 1) of \(images.count)")
            }
        }
        .task(id: selection) {
            await loadCurrent()
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    guard !isZoomed else { return }
                    if value.translation.height > 100 {
                        onDismiss()
                    }
                }
        )
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(DesignTheme.textPrimary)
                .frame(width: 44, height: 44)
                .background { chromeBackground }
        }
        .accessibilityLabel("Close")
    }

    @ViewBuilder
    private var chromeBackground: some View {
        if reduceTransparency {
            Capsule()
                .fill(DesignTheme.surface)
        } else {
            Capsule()
                .glassEffect()
        }
    }

    private func loadCurrent() async {
        image = nil
        isZoomed = false
        guard let item = images.first(where: { $0.id == selection }) else { return }
        let targetWidth: CGFloat = 1280
        guard let url = ImageLoader.imageURL(
            path: item.filePath,
            kind: .backdrop,
            targetWidthPoints: targetWidth,
            scale: displayScale
        ) else { return }
        let expected = item.filePath
        let loaded = try? await imageLoader.image(
            for: url,
            targetSize: CGSize(width: targetWidth, height: targetWidth * 9 / 16),
            scale: displayScale
        )
        guard expected == item.filePath else { return }
        image = loaded
    }
}
