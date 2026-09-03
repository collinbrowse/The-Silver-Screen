//
//  MovieTableViewCell.swift
//  URBNFlicks
//
//  Created by URBN
//

import Foundation
import UIKit


class MovieTableViewCell: UITableViewCell {
    
    let posterView = UIImageView()
    let titleLabel = UILabel()
    let releaseYearLabel = UILabel()
    let ratingLabel = UILabel()
    
    let padding = 14.0
        
    required override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        setupContentView()
    }
    
    func configure(with detail: MovieSummary) {
        if let posterPath = detail.poster_path,
            let imgUrl = URL(string: "https://image.tmdb.org/t/p/w500/" + posterPath),
            let data = try? Data(contentsOf: imgUrl) {
            posterView.image = UIImage(data: data)
        }
        
        titleLabel.text = detail.title
        releaseYearLabel.text = "Released: " + detail.release_date
        ratingLabel.text = "Rating: " + String(detail.vote_average) + " / 10"
    }
    
    func setupContentView() {
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
