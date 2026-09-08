//
//  MovieTableViewCell.swift
//  URBNFlicks
//
//  Created by URBN
//

import Foundation
import UIKit

final class MovieTableViewCell: UITableViewCell {

    static let reuseIdentifier = "MovieTableViewCell"
    static let posterSize = CGSize(width: 128, height: 176)

    let posterView = UIImageView()
    let titleLabel = UILabel()
    let releaseYearLabel = UILabel()
    let ratingLabel = UILabel()

    private let padding: CGFloat = 8
    private let titleToRatingSpacing: CGFloat = 6
    private let minRatingToYearSpacing: CGFloat = 6

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    required override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupContentView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with movie: Movie) {
        if let posterPath = movie.posterPath,
           let imgUrl = URL(string: "https://image.tmdb.org/t/p/w500" + (posterPath.hasPrefix("/") ? posterPath : "/" + posterPath)),
           let data = try? Data(contentsOf: imgUrl) {
            posterView.image = UIImage(data: data)
        } else {
            posterView.image = nil
        }

        titleLabel.text = movie.title
        ratingLabel.text = Self.ratingText(for: movie.voteAverage)
        releaseYearLabel.text = Self.releaseYearText(for: movie.releaseDate)
    }

    static func ratingText(for voteAverage: Double) -> String {
        String(format: "Rating: %.1f", voteAverage)
    }

    static func releaseYearText(for releaseDate: Date?) -> String {
        guard let releaseDate else { return "Released: " }
        return "Released: " + yearFormatter.string(from: releaseDate)
    }

    private func setupContentView() {
        selectionStyle = .default

        posterView.translatesAutoresizingMaskIntoConstraints = false
        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        posterView.setContentHuggingPriority(.required, for: .horizontal)
        posterView.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: .systemFont(ofSize: 14, weight: .bold)
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        ratingLabel.translatesAutoresizingMaskIntoConstraints = false
        ratingLabel.font = UIFontMetrics(forTextStyle: .caption2).scaledFont(
            for: .italicSystemFont(ofSize: 10)
        )
        ratingLabel.adjustsFontForContentSizeCategory = true
        ratingLabel.numberOfLines = 1
        ratingLabel.setContentHuggingPriority(.required, for: .vertical)
        ratingLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        releaseYearLabel.translatesAutoresizingMaskIntoConstraints = false
        releaseYearLabel.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .systemFont(ofSize: 12)
        )
        releaseYearLabel.adjustsFontForContentSizeCategory = true
        releaseYearLabel.numberOfLines = 1
        releaseYearLabel.setContentHuggingPriority(.required, for: .vertical)
        releaseYearLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        contentView.addSubview(posterView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(ratingLabel)
        contentView.addSubview(releaseYearLabel)

        let bottomConstraint = posterView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -padding
        )
        bottomConstraint.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            posterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            posterView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
            bottomConstraint,
            posterView.widthAnchor.constraint(equalToConstant: Self.posterSize.width),
            posterView.heightAnchor.constraint(equalToConstant: Self.posterSize.height),

            titleLabel.leadingAnchor.constraint(equalTo: posterView.trailingAnchor, constant: padding),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            titleLabel.topAnchor.constraint(equalTo: posterView.topAnchor),

            ratingLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            ratingLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            ratingLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: titleToRatingSpacing),

            releaseYearLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            releaseYearLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            releaseYearLabel.bottomAnchor.constraint(equalTo: posterView.bottomAnchor),
            releaseYearLabel.topAnchor.constraint(
                greaterThanOrEqualTo: ratingLabel.bottomAnchor,
                constant: minRatingToYearSpacing
            ),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    override var accessibilityLabel: String? {
        get {
            [titleLabel.text, ratingLabel.text, releaseYearLabel.text]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
        set { }
    }
}
