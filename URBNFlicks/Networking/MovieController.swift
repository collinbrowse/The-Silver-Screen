//
//  MovieController.swift
//  URBNFlicks
//
//  Created by URBN
//

import Foundation


struct MovieController {
    
    enum RequestError: String, Error {
        case missingResponse = "No Response Data"
    }
    
    let apiKey: String
    
    init() {
        apiKey = APIKeys.tmdb
    }
    
    func getTopMovies(completion: @escaping (Result<[MovieSummary], Error>) -> Void) {
        guard let url = URL(string: "https://api.themoviedb.org/3/discover/movie?&language=en-US&sort_by=vote_average.desc&vote_count.gte=200&without_genres=99,10755&page=1&api_key=" + apiKey) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        func callResultHandler(_ result: Result<[MovieSummary], Error>) {
            DispatchQueue.main.async {
                completion(result)
            }
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            
            if let error = error {
                callResultHandler(.failure(error))
                return
            }
            
            guard let data = data else {
                callResultHandler(.failure(RequestError.missingResponse))
                return
            }
            
            let jsonDecoder = JSONDecoder()
            do {
                let list = try jsonDecoder.decode(MovieList.self, from: data)
                callResultHandler(.success(list.results))
            }
            catch {
                callResultHandler(.failure(error))
            }
            
        }
        
        task.resume()
    }
}
