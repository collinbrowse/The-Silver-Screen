//
//  TMDBFixtures.swift
//  URBNFlicksTests
//
//  Trimmed TMDB JSON for offline tests. No live network, no full payloads.
//

import Foundation

enum TMDBFixtures {
    /// One-page discover response with two well-formed movies.
    static let topMoviesPage1 = Data(
        """
        {
          "page": 1,
          "results": [
            {
              "adult": false,
              "backdrop_path": "/backdrop.jpg",
              "genre_ids": [18, 80],
              "id": 278,
              "original_language": "en",
              "original_title": "The Shawshank Redemption",
              "overview": "Framed in the 1940s for a double murder.",
              "popularity": 100.0,
              "poster_path": "/poster.jpg",
              "release_date": "1994-09-23",
              "title": "The Shawshank Redemption",
              "video": false,
              "vote_average": 8.7,
              "vote_count": 25000
            },
            {
              "adult": false,
              "backdrop_path": null,
              "genre_ids": [18],
              "id": 238,
              "original_language": "en",
              "original_title": "The Godfather",
              "overview": "The aging patriarch of an organized crime dynasty.",
              "popularity": 90.0,
              "poster_path": "/godfather.jpg",
              "release_date": "1972-03-14",
              "title": "The Godfather",
              "video": false,
              "vote_average": 8.7,
              "vote_count": 18000
            }
          ],
          "total_pages": 2,
          "total_results": 3
        }
        """.utf8
    )

    /// Same shape, but one result has an empty release_date (TMDB does this).
    static let topMoviesWithEmptyReleaseDate = Data(
        """
        {
          "page": 1,
          "results": [
            {
              "adult": false,
              "backdrop_path": null,
              "genre_ids": [28],
              "id": 999,
              "original_language": "en",
              "original_title": "Untitled",
              "overview": "Missing a release date.",
              "popularity": 1.0,
              "poster_path": null,
              "release_date": "",
              "title": "Untitled",
              "video": false,
              "vote_average": 5.0,
              "vote_count": 200
            }
          ],
          "total_pages": 1,
          "total_results": 1
        }
        """.utf8
    )

    /// Trimmed `/movie/{id}` payload for Story 1 fields.
    static let movieDetailShawshank = Data(
        """
        {
          "id": 278,
          "title": "The Shawshank Redemption",
          "overview": "Framed in the 1940s for a double murder.",
          "poster_path": "/poster.jpg",
          "release_date": "1994-09-23",
          "vote_average": 8.7,
          "budget": 25000000,
          "revenue": 28341469,
          "genres": [
            {"id": 18, "name": "Drama"},
            {"id": 80, "name": "Crime"}
          ]
        }
        """.utf8
    )

    /// Detail with missing optional financials and empty release date.
    static let movieDetailSparse = Data(
        """
        {
          "id": 999,
          "title": "Untitled",
          "overview": "",
          "poster_path": null,
          "release_date": "",
          "vote_average": 5.0,
          "budget": 0,
          "revenue": 0,
          "genres": []
        }
        """.utf8
    )
}
