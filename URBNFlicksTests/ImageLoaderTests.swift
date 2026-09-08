//
//  ImageLoaderTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

final class ImageLoaderTests: XCTestCase {

    func test_posterURL_selectsW342_for128ptAt2x() {
        let url = ImageLoader.posterURL(path: "/poster.jpg", targetWidthPoints: 128, scale: 2)

        XCTAssertEqual(url?.absoluteString, "https://image.tmdb.org/t/p/w342/poster.jpg")
    }

    func test_posterURL_selectsW92_forNarrowTarget() {
        let url = ImageLoader.posterURL(path: "poster.jpg", targetWidthPoints: 40, scale: 2)

        XCTAssertEqual(url?.absoluteString, "https://image.tmdb.org/t/p/w92/poster.jpg")
    }

    func test_posterURL_selectsW500_forLargeTarget() {
        let url = ImageLoader.posterURL(path: "/poster.jpg", targetWidthPoints: 200, scale: 3)

        XCTAssertEqual(url?.absoluteString, "https://image.tmdb.org/t/p/w500/poster.jpg")
    }

    @MainActor
    func test_cell_prepareForReuse_clearsPosterAndAllowsReconfigure() {
        let cell = MovieTableViewCell(style: .default, reuseIdentifier: MovieTableViewCell.reuseIdentifier)
        let loader = ImageLoader(client: FakeHTTPClient(stub: .failure(URLError(.notConnectedToInternet))))
        let movie = TestMovies.make(id: 10, title: "One", posterPath: "/a.jpg", releaseDate: TestMovies.date("2001-01-01"))

        cell.configure(with: movie, loader: loader, isFavorite: false, onFavoriteToggle: {})
        cell.prepareForReuse()

        XCTAssertNil(cell.titleLabel.text)
        XCTAssertNotNil(cell.posterView.image)

        let next = TestMovies.make(id: 11, title: "Two", releaseDate: TestMovies.date("2002-02-02"))
        cell.configure(with: next, loader: loader, isFavorite: true, onFavoriteToggle: {})
        XCTAssertEqual(cell.titleLabel.text, "Two")
    }
}
