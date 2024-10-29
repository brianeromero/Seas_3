//
//  SendGridEmailService.swift
//  Seas_3
//
//  Created by Brian Romero on 10/10/24.
//

import Foundation

class SendGridEmailService {
    // Securely read the API key from the Config.plist
    private var apiKey: String {
        guard let config = ConfigLoader.loadConfigValues() else {
            fatalError("Failed to load Config.plist")
        }
        guard let key = config.SENDGRID_API_KEY else {
            fatalError("SendGrid API Key is missing from Config.plist")
        }
        return key
    }


    // Sends a custom email using the SendGrid API
    func sendEmail(to recipientEmail: String, subject: String, content: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://api.sendgrid.com/v3/mail/send") else {
            print("Invalid SendGrid URL")
            completion(false)
            return
        }

        let payload: [String: Any] = [
            "personalizations": [
                [
                    "to": [
                        ["email": recipientEmail]
                    ],
                    "subject": subject
                ]
            ],
            "from": [
                "email": "mfinder.bjj@gmail.com"
            ],
            "content": [
                [
                    "type": "text/plain",
                    "value": content
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            print("Failed to serialize JSON")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to send email: \(error.localizedDescription)")
                completion(false)
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 202 {
                print("Email sent successfully via SendGrid!")
                completion(true)
            } else {
                print("Failed to send email. HTTP Response: \(response.debugDescription)")
                completion(false)
            }
        }
        task.resume()
    }
}
