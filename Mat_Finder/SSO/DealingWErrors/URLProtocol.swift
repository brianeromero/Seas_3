//
//  URLProtocol.swift
//  Mat_Finder
//
//  Created by Brian Romero on 5/13/25.
//

import Foundation


class DebugURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        // You can fine-tune this to only intercept Google OAuth requests
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        if let url = request.url {
            print("🔗 [DebugURLProtocol] Request URL: \(url)")
            
            // Log query parameters
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                print("📦 [Query Parameters]")
                components.queryItems?.forEach {
                    print("  \($0.name): \($0.value ?? "nil")")
                }
            }
        }

        if let headers = request.allHTTPHeaderFields {
            print("🧾 [Headers]")
            headers.forEach { print("  \($0): \($1)") }
        }

        if let httpBody = request.httpBody {
            let bodyString = String(data: httpBody, encoding: .utf8) ?? "N/A"
            print("📄 [Body]: \(bodyString)")
        }

        // Since this is a logger, we need to finish the protocol cleanly.
        let dummyResponse = URLResponse(url: request.url!, mimeType: "text/plain", expectedContentLength: 0, textEncodingName: nil)
        client?.urlProtocol(self, didReceive: dummyResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // Not used in logging
    }
}
