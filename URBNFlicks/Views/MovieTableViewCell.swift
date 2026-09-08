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

    let posterView = UIImageView()
    let titleLabel = UILabel()
    let releaseYearLabel = UILabel()
    let ratingLabel = UILabel()

    let padding = 14.0

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
        ratingLabel.text = "Rating: " + String(movie.voteAverage) + " / 10"
        if let releaseDate = movie.releaseDate {
            releaseYearLabel.text = "Released: " + Self.yearFormatter.string(from: releaseDate)
        } else {
            releaseYearLabel.text = "Released: "
        }
    }

    private func setupContentView() {
        let labelStack = UIStackView(arrangedSubviews: [titleLabel, ratingLabel, releaseYearLabel])
        labelStack.axis = .vertical

        let fullStack = UIStackView(arrangedSubviews: [posterView, labelStack])
        fullStack.axis = .horizontal
        fullStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fullStack)

        fullStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding).isActive = true
        fullStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding).isActive = true
        fullStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding).isActive = true
        fullStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding).isActive = true
    }
}
