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

    /// Second discover page; used with `topMoviesPage1` for paging tests.
    static let topMoviesPage2 = Data(
        """
        {
          "page": 2,
          "results": [
            {
              "adult": false,
              "backdrop_path": null,
              "genre_ids": [18],
              "id": 240,
              "original_language": "en",
              "original_title": "The Godfather Part II",
              "overview": "The early life and career of Vito Corleone.",
              "popularity": 85.0,
              "poster_path": "/godfather2.jpg",
              "release_date": "1974-12-20",
              "title": "The Godfather Part II",
              "video": false,
              "vote_average": 8.6,
              "vote_count": 12000
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

    /// Detail with appended images, credits, and similar.
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
          ],
          "belongs_to_collection": null,
          "images": {
            "backdrops": [
              {"file_path": "/backdrop-b.jpg", "vote_average": 5.2},
              {"file_path": "/backdrop-a.jpg", "vote_average": 8.1},
              {"file_path": "", "vote_average": 9.0}
            ],
            "posters": []
          },
          "credits": {
            "cast": [
              {
                "id": 504,
                "credit_id": "cast-1",
                "name": "Tim Robbins",
                "character": "Andy Dufresne",
                "profile_path": "/tim.jpg",
                "order": 0,
                "known_for_department": "Acting"
              },
              {
                "id": 192,
                "credit_id": "cast-2",
                "name": "Morgan Freeman",
                "character": "Ellis Boyd Redding",
                "profile_path": "/morgan.jpg",
                "order": 1,
                "known_for_department": "Acting"
              }
            ],
            "crew": [
              {
                "id": 4027,
                "credit_id": "crew-dir",
                "name": "Frank Darabont",
                "job": "Director",
                "department": "Directing",
                "profile_path": "/frank.jpg",
                "known_for_department": "Directing"
              },
              {
                "id": 4027,
                "credit_id": "crew-write",
                "name": "Frank Darabont",
                "job": "Screenplay",
                "department": "Writing",
                "profile_path": "/frank.jpg"
              },
              {
                "id": 123,
                "credit_id": "crew-cam",
                "name": "Camera Person",
                "job": "Director of Photography",
                "department": "Camera",
                "profile_path": null
              }
            ]
          },
          "similar": {
            "results": [
              {
                "id": 311,
                "title": "Once Upon a Time in America",
                "poster_path": "/once.jpg",
                "release_date": "1984-02-17",
                "vote_average": 8.4,
                "genre_ids": [18, 80]
              },
              {
                "id": 311,
                "title": "Once Upon a Time in America",
                "poster_path": "/once.jpg",
                "release_date": "1984-02-17",
                "vote_average": 8.4,
                "genre_ids": [18, 80]
              }
            ]
          }
        }
        """.utf8
    )

    /// Detail with missing optional financials and empty release date; no sections.
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
          "genres": [],
          "belongs_to_collection": null,
          "images": {"backdrops": [], "posters": []},
          "credits": {"cast": [], "crew": []},
          "similar": {"results": []}
        }
        """.utf8
    )

    /// Movie that belongs to a multi-part collection.
    static let movieDetailWithCollection = Data(
        """
        {
          "id": 238,
          "title": "The Godfather",
          "overview": "The aging patriarch.",
          "poster_path": "/godfather.jpg",
          "release_date": "1972-03-14",
          "vote_average": 8.7,
          "budget": 6000000,
          "revenue": 245066411,
          "genres": [{"id": 18, "name": "Drama"}],
          "belongs_to_collection": {
            "id": 230,
            "name": "The Godfather Collection",
            "poster_path": "/collection.jpg"
          },
          "images": {"backdrops": [], "posters": []},
          "credits": {"cast": [], "crew": []},
          "similar": {"results": []}
        }
        """.utf8
    )

    static let collectionGodfather = Data(
        """
        {
          "id": 230,
          "name": "The Godfather Collection",
          "parts": [
            {
              "id": 238,
              "title": "The Godfather",
              "poster_path": "/godfather.jpg",
              "release_date": "1972-03-14",
              "vote_average": 8.7,
              "genre_ids": [18]
            },
            {
              "id": 240,
              "title": "The Godfather Part II",
              "poster_path": "/gf2.jpg",
              "release_date": "1974-12-20",
              "vote_average": 8.6,
              "genre_ids": [18]
            }
          ]
        }
        """.utf8
    )

    /// Collection whose only part is the requested movie.
    static let collectionSolo = Data(
        """
        {
          "id": 230,
          "name": "Solo Collection",
          "parts": [
            {
              "id": 238,
              "title": "The Godfather",
              "poster_path": "/godfather.jpg",
              "release_date": "1972-03-14",
              "vote_average": 8.7,
              "genre_ids": [18]
            }
          ]
        }
        """.utf8
    )

    static let movieReviewsPage1 = Data(
        """
        {
          "page": 1,
          "total_pages": 2,
          "results": [
            {
              "id": "rev-1",
              "author": "Alice",
              "content": "A masterpiece of cinema that holds up decades later.",
              "updated_at": "2021-04-04T22:36:53.454Z",
              "author_details": {"username": "alice_reviews"}
            }
          ]
        }
        """.utf8
    )

    static let movieReviewsPage2 = Data(
        """
        {
          "page": 2,
          "total_pages": 2,
          "results": [
            {
              "id": "rev-2",
              "author": "Bob",
              "content": "Still the gold standard for prison dramas.",
              "updated_at": "2022-01-15T10:00:00Z",
              "author_details": {"username": "bob"}
            }
          ]
        }
        """.utf8
    )

    static let movieReviewsEmpty = Data(
        """
        {
          "page": 1,
          "total_pages": 1,
          "results": []
        }
        """.utf8
    )

    /// Person detail with bio, deathday, IMDb id, images, and movie+TV cast/crew credits.
    static let personDetailMorganFreeman = Data(
        """
        {
          "id": 1922,
          "name": "Morgan Freeman",
          "biography": "An American actor known for his distinctive voice.",
          "birthday": "1937-06-01",
          "deathday": null,
          "place_of_birth": "Memphis, Tennessee, USA",
          "profile_path": "/oYJ3x8VfQU04f6ihfTXBL5H2OKD.jpg",
          "known_for_department": "Acting",
          "images": {
            "profiles": [
              {"file_path": "/profile1.jpg", "vote_average": 5.2},
              {"file_path": "/profile2.jpg", "vote_average": 4.1}
            ]
          },
          "external_ids": {
            "imdb_id": "nm0000151"
          },
          "combined_credits": {
            "cast": [
              {
                "id": 278,
                "media_type": "movie",
                "title": "The Shawshank Redemption",
                "poster_path": "/poster.jpg",
                "release_date": "1994-09-23",
                "genre_ids": [18, 80],
                "character": "Ellis Boyd 'Red' Redding",
                "popularity": 100.0
              },
              {
                "id": 1396,
                "media_type": "tv",
                "name": "Breaking Bad",
                "poster_path": "/bb.jpg",
                "first_air_date": "2008-01-20",
                "genre_ids": [18, 80],
                "character": "Guest",
                "popularity": 50.0
              }
            ],
            "crew": [
              {
                "id": 550,
                "media_type": "movie",
                "title": "Fight Club",
                "poster_path": "/fc.jpg",
                "release_date": "1999-10-15",
                "genre_ids": [18],
                "job": "Executive Producer",
                "popularity": 80.0
              },
              {
                "id": 550,
                "media_type": "movie",
                "title": "Fight Club",
                "poster_path": "/fc.jpg",
                "release_date": "1999-10-15",
                "genre_ids": [18],
                "job": "Producer",
                "popularity": 80.0
              }
            ]
          }
        }
        """.utf8
    )

    /// Sparse person: no images, no credits, no deathday, no imdb.
    static let personDetailSparse = Data(
        """
        {
          "id": 1,
          "name": "Unknown Actor",
          "biography": "",
          "birthday": null,
          "deathday": null,
          "place_of_birth": null,
          "profile_path": null,
          "known_for_department": null,
          "images": {"profiles": []},
          "external_ids": {"imdb_id": null},
          "combined_credits": {"cast": [], "crew": []}
        }
        """.utf8
    )

    /// Deceased person with many cast credits (>10) for View All threshold tests.
    static let personDetailManyCredits: Data = {
        let castItems = (1...12).map { i in
            """
              {
                "id": \(i),
                "media_type": "movie",
                "title": "Movie \(i)",
                "poster_path": "/m\(i).jpg",
                "release_date": "200\(i % 10)-01-01",
                "genre_ids": [18],
                "character": "Role \(i)",
                "popularity": \(100 - i)
              }
            """
        }.joined(separator: ",\n")
        return Data(
            """
            {
              "id": 123,
              "name": "Busy Actor",
              "biography": "Lots of credits.",
              "birthday": "1950-01-01",
              "deathday": "2020-12-31",
              "place_of_birth": "Los Angeles, USA",
              "profile_path": "/busy.jpg",
              "known_for_department": "Acting",
              "images": {"profiles": [{"file_path": "/busy1.jpg", "vote_average": 1.0}]},
              "external_ids": {"imdb_id": "nm9999999"},
              "combined_credits": {
                "cast": [
            \(castItems)
                ],
                "crew": []
              }
            }
            """.utf8
        )
    }()
}
