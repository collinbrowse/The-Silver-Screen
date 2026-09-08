//
//  MovieTableViewCellTests.swift
//  URBNFlicksTests
//

import XCTest
@testable import URBNFlicks

@MainActor
final class MovieTableViewCellTests: XCTestCase {

    func test_configure_formatsRatingToOneDecimal_withoutOutOfTen() {
        let cell = MovieTableViewCell(style: .default, reuseIdentifier: MovieTableViewCell.reuseIdentifier)
        cell.configure(with: TestMovies.make(releaseDate: TestMovies.date("1994-09-23"), voteAverage: 8.74))

        XCTAssertEqual(cell.ratingLabel.text, "Rating: 8.7")
        XCTAssertFalse(cell.ratingLabel.text?.contains("/ 10") ?? true)
    }

    func test_configure_usesReleaseYearOnly() {
        let cell = MovieTableViewCell(style: .default, reuseIdentifier: MovieTableViewCell.reuseIdentifier)
        cell.configure(with: TestMovies.make(releaseDate: TestMovies.date("1981-06-12"), voteAverage: 9.2))

        XCTAssertEqual(cell.releaseYearLabel.text, "Released: 1981")
    }

    func test_configure_nilReleaseDate_doesNotUseRawDateString() {
        let cell = MovieTableViewCell(style: .default, reuseIdentifier: MovieTableViewCell.reuseIdentifier)
        cell.configure(with: TestMovies.make(releaseDate: nil, voteAverage: 5.0))

        XCTAssertEqual(cell.releaseYearLabel.text, "Released: ")
        XCTAssertFalse(cell.releaseYearLabel.text?.contains("-") ?? true)
    }

    func test_layout_posterMatchesRedlineSizeAndAspectFill() {
        let cell = laidOutCell(title: "Short Movie Title")

        XCTAssertEqual(cell.posterView.bounds.width, 128, accuracy: 0.5)
        XCTAssertEqual(cell.posterView.bounds.height, 176, accuracy: 0.5)
        XCTAssertEqual(cell.posterView.contentMode, .scaleAspectFill)
        XCTAssertTrue(cell.posterView.clipsToBounds)
    }

    func test_layout_titleAndRatingPinNearTop_yearPinsToBottom() {
        let cell = laidOutCell(
            title: "This is a very long movie title that should wrap across multiple lines In 3D"
        )

        let padding: CGFloat = 8
        XCTAssertEqual(cell.titleLabel.frame.minY, cell.posterView.frame.minY, accuracy: 0.5)
        XCTAssertEqual(
            cell.ratingLabel.frame.minY,
            cell.titleLabel.frame.maxY + 6,
            accuracy: 0.5
        )
        XCTAssertEqual(cell.releaseYearLabel.frame.maxY, cell.posterView.frame.maxY, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(
            cell.releaseYearLabel.frame.minY - cell.ratingLabel.frame.maxY,
            6 - 0.5
        )
        XCTAssertGreaterThan(cell.titleLabel.frame.height, 20)
        XCTAssertEqual(cell.posterView.frame.minX, padding, accuracy: 0.5)
        XCTAssertEqual(cell.posterView.frame.minY, padding, accuracy: 0.5)
    }

    private func laidOutCell(title: String) -> MovieTableViewCell {
        let cell = MovieTableViewCell(style: .default, reuseIdentifier: MovieTableViewCell.reuseIdentifier)
        cell.configure(
            with: TestMovies.make(title: title, releaseDate: TestMovies.date("1981-01-01"), voteAverage: 9.2)
        )

        let width: CGFloat = 390
        let targetSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let height = cell.contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        cell.frame = CGRect(x: 0, y: 0, width: width, height: height)
        cell.layoutIfNeeded()
        return cell
    }
}
