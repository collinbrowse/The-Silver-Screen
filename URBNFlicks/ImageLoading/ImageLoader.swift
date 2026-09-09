//
//  ImageLoader.swift
//  URBNFlicks
//

import Foundation
import UIKit
import ImageIO

actor ImageLoader {
    private let client: any HTTPClient
    private let logger: any AppLogging
    private let sleeper: any Sleeper
    private let memoryCache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    init(
        client: any HTTPClient,
        logger: any AppLogging,
        sleeper: any Sleeper = TaskSleeper()
    ) {
        self.client = client
        self.logger = logger
        self.sleeper = sleeper
        memoryCache.countLimit = 200
    }

    func image(for url: URL, targetSize: CGSize, scale: CGFloat) async throws -> UIImage {
        let cacheKey = url as NSURL
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }

        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task<UIImage, Error> {
            let request = URLRequest(url: url)
            let data = try await HTTPTransport.data(
                for: request,
                client: client,
                logger: logger,
                context: "Image",
                sleeper: sleeper
            )
            return try Self.downsample(data: data, targetSize: targetSize, scale: scale)
        }

        inFlight[url] = task
        defer { inFlight[url] = nil }

        do {
            let image = try await task.value
            memoryCache.setObject(image, forKey: cacheKey)
            return image
        } catch is CancellationError {
            throw CancellationError()
        }
    }

    func prefetch(urls: [URL], targetSize: CGSize, scale: CGFloat) {
        for url in urls {
            Task { try? await image(for: url, targetSize: targetSize, scale: scale) }
        }
    }

    func cancelPrefetch(urls: [URL]) {
        for url in urls {
            inFlight[url]?.cancel()
            inFlight[url] = nil
        }
    }

    // MARK: - TMDB size selection

    enum ImageKind: Sendable {
        case poster
        case backdrop
        case profile
    }

    static func posterURL(path: String, targetWidthPoints: CGFloat, scale: CGFloat) -> URL? {
        let pixels = targetWidthPoints * scale
        let sizeToken: String
        switch pixels {
        case ..<92: sizeToken = "w92"
        case ..<154: sizeToken = "w154"
        case ..<185: sizeToken = "w185"
        case ..<342: sizeToken = "w342"
        default: sizeToken = "w500"
        }
        let normalized = path.hasPrefix("/") ? path : "/" + path
        return URL(string: "https://image.tmdb.org/t/p/\(sizeToken)\(normalized)")
    }

    static func imageURL(
        path: String,
        kind: ImageKind,
        targetWidthPoints: CGFloat,
        scale: CGFloat
    ) -> URL? {
        if kind == .poster {
            // Carousel/fullscreen posters may request larger than list cells.
            let pixels = targetWidthPoints * scale
            let sizeToken: String
            switch pixels {
            case ..<92: sizeToken = "w92"
            case ..<154: sizeToken = "w154"
            case ..<185: sizeToken = "w185"
            case ..<342: sizeToken = "w342"
            case ..<500: sizeToken = "w500"
            default: sizeToken = "w780"
            }
            let normalized = path.hasPrefix("/") ? path : "/" + path
            return URL(string: "https://image.tmdb.org/t/p/\(sizeToken)\(normalized)")
        }
        let pixels = targetWidthPoints * scale
        let sizeToken = sizeToken(for: kind, pixels: pixels)
        let normalized = path.hasPrefix("/") ? path : "/" + path
        return URL(string: "https://image.tmdb.org/t/p/\(sizeToken)\(normalized)")
    }

    private static func sizeToken(for kind: ImageKind, pixels: CGFloat) -> String {
        switch kind {
        case .poster:
            return "w500"
        case .backdrop:
            switch pixels {
            case ..<300: return "w300"
            case ..<780: return "w780"
            default: return "w1280"
            }
        case .profile:
            switch pixels {
            case ..<45: return "w45"
            case ..<185: return "w185"
            default: return "h632"
            }
        }
    }

    // MARK: - Downsampling

    private static func downsample(data: Data, targetSize: CGSize, scale: CGFloat) throws -> UIImage {
        let maxPixelSize = max(targetSize.width, targetSize.height) * scale
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            throw AppError.decoding
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            downsampleOptions as CFDictionary
        ) else {
            throw AppError.decoding
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}
