/*
//
//  APIClient.swift
//  Mat_Finder
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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"  // Change to POST
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // Set content type if needed
        
        // Optionally, if you need to send data (like user credentials or data):
        // let body: [String: Any] = ["key": "value"] // Customize this
        // request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
            } else if let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    completion(json?["token"] as? String, nil) // Ensure you're accessing the correct key
                } catch {
                    completion(nil, error)
                }
            }
        }.resume()
    }
}
*/
