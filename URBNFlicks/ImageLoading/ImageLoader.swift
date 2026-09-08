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
        return URL(string: "https://image.tmdb.org/t/p/\(sizeToken)\(path.hasPrefix("/") ? path : "/" + path)")
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
