//
//  CustomAuthorizationService.swift
//  Mat_Finder
//
//  Created by Brian Romero on 5/20/25.
//

import Foundation
import AppAuth


class CustomAuthorizationService {

    static func performTokenRequest(
        _ request: OIDTokenRequest,
        originalAuthorizationResponse response: OIDAuthorizationResponse?,
        callback: @escaping OIDTokenCallback
    ) {
        // Get URLRequest from OIDTokenRequest (no try needed)
        let urlRequest = request.urlRequest()
        print("🔗 Request: \(urlRequest.httpMethod ?? "") \(urlRequest.url?.absoluteString ?? "")")
        print("📦 Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        if let body = urlRequest.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("📄 Body: \(bodyString)")
        }

        // Modify headers
        var modifiedRequest = urlRequest
        modifiedRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        modifiedRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        print("🔗 Request: \(modifiedRequest.httpMethod ?? "") \(modifiedRequest.url?.absoluteString ?? "")")
        print("📦 Headers: \(modifiedRequest.allHTTPHeaderFields ?? [:])")
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: modifiedRequest) { data, response, error in
            if let error = error {
                callback(nil, error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                let err = NSError(domain: "CustomAuthorizationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
                callback(nil, err)
                return
            }

            print("📶 HTTP Status Code: \(httpResponse.statusCode)")
            print("📦 Response Headers: \(httpResponse.allHeaderFields)")


            guard let data = data else {
                let err = NSError(domain: "CustomAuthorizationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                callback(nil, err)
                return
            }

            // ✅ Add this check before parsing JSON
            guard data.count > 0 else {
                let err = NSError(domain: "CustomAuthorizationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty token response"])
                callback(nil, err)
                return
            }
            
            // ✅ Log full response body
            print("📥 Raw Token Response Data: \(String(data: data, encoding: .utf8) ?? "Unreadable Data")")


            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    let err = NSError(domain: "CustomAuthorizationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
                    callback(nil, err)
                    return
                }

                var nsDict = [String: NSCopying & NSObjectProtocol]()
                for (key, value) in json {
                    if let nsValue = value as? NSCopying & NSObjectProtocol {
                        nsDict[key] = nsValue
                    }
                }

                let tokenResponse = OIDTokenResponse(request: request, parameters: nsDict)
                callback(tokenResponse, nil)
            } catch {
                callback(nil, error)
            }
        }
        task.resume()
    }
}
