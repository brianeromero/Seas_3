//
//  LoggingURLProtocol.swift
//  Seas_3
//
//  Created by Brian Romero on 4/21/25.
//

import Foundation
import os

class LoggingURLProtocol: URLProtocol {

    private var sessionTask: URLSessionDataTask?

    override class func canInit(with request: URLRequest) -> Bool {
        if URLProtocol.property(forKey: "LoggingHandledKey", in: request) != nil {
            return false
        }
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        os_log("Request: %@", log: GeocodingLogger.geocoding, type: .info, request.description)
        os_log("Request headers: %@", log: GeocodingLogger.geocoding, type: .info, request.allHTTPHeaderFields ?? [:])

        // Convert to NSMutableURLRequest to set the handled key
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: "LoggingHandledKey", in: mutableRequest)

        // Create session without this protocol to avoid recursion
        let config = URLSessionConfiguration.default
        config.protocolClasses = []

        let session = URLSession(configuration: config)

        sessionTask = session.dataTask(with: mutableRequest as URLRequest) { data, response, error in
            if let data = data {
                os_log("Received response: %@", log: GeocodingLogger.geocoding, type: .info, String(data: data, encoding: .utf8) ?? "Invalid response data")
                self.client?.urlProtocol(self, didLoad: data)
            }

            if let response = response {
                os_log("Response headers: %@", log: GeocodingLogger.geocoding, type: .info, (response as? HTTPURLResponse)?.allHeaderFields ?? [:])
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }

            if let error = error {
                os_log("Error: %@", log: GeocodingLogger.geocoding, type: .error, error.localizedDescription)
                self.client?.urlProtocol(self, didFailWithError: error)
            } else {
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }

        sessionTask?.resume()
    }

    override func stopLoading() {
        sessionTask?.cancel()
    }
}
