//
//  APIClient.swift
//  Seas_3
//
//  Created by Brian Romero on 10/28/24.
//

import Foundation

class APIClient {
  func getCustomToken(completion: @escaping (String?, Error?) -> Void) {
    guard let url = URL(string: "https://your-server-url.com/getCustomToken") else {
      completion(nil, NSError(domain: "Invalid URL", code: 404, userInfo: nil))
      return
    }
    
    URLSession.shared.dataTask(with: url) { data, response, error in
      if let error = error {
        completion(nil, error)
      } else if let data = data {
        do {
          let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String]
          completion(json?["token"], nil)
        } catch {
          completion(nil, error)
        }
      }
    }.resume()
  }
}
