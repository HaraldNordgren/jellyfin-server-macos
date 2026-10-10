//
// Jellyfin Server is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2022 Jellyfin & Jellyfin Contributors
//

import Foundation
import Security

struct ActionError: LocalizedError {
    let errorDescription: String?

    init(_ message: String) {
        errorDescription = message
    }
}

/// Pairs the menu bar app with the local server through Quick Connect, so the app can call
/// authenticated endpoints without the user having to copy an API key.
enum QuickConnect {
    private static let deviceIdKey = "QuickConnectDeviceId"
    private static let pollInterval: UInt64 = 2 * 1_000_000_000
    private static let pollAttempts = 150

    private struct Initiation: Decodable {
        let code: String
        let secret: String

        enum CodingKeys: String, CodingKey {
            case code = "Code"
            case secret = "Secret"
        }
    }

    private struct Status: Decodable {
        let authenticated: Bool

        enum CodingKeys: String, CodingKey {
            case authenticated = "Authenticated"
        }
    }

    private struct AuthenticationResult: Decodable {
        let accessToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "AccessToken"
        }
    }

    private static var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: deviceIdKey) {
            return id
        }

        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceIdKey)
        return id
    }

    static func authorizationHeader(token: String? = nil) -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.1"
        var header = "MediaBrowser Client=\"Jellyfin Server macOS\", Device=\"\(Host.current().localizedName ?? "Mac")\", DeviceId=\"\(deviceId)\", Version=\"\(version)\""

        if let token = token {
            header += ", Token=\"\(token)\""
        }

        return header
    }

    private static func request(_ baseURL: String, _ path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: .init(string: baseURL + path)!)
        request.httpMethod = method
        request.setValue(authorizationHeader(), forHTTPHeaderField: "Authorization")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        return request
    }

    private static func send<T: Decodable>(_ request: URLRequest, as _: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw ActionError("The Jellyfin server did not accept the pairing request.")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Requests a pairing code, calls `onCode` so the user can enter it in the web UI, then waits for the
    /// approval and returns the access token of the approving user.
    static func pair(baseURL: String, onCode: (String) -> Void) async throws -> String {
        let initiation = try await send(request(baseURL, "/QuickConnect/Initiate", method: "POST"), as: Initiation.self)
        onCode(initiation.code)

        for _ in 0 ..< pollAttempts {
            try await Task.sleep(nanoseconds: pollInterval)

            let status = try await send(request(baseURL, "/QuickConnect/Connect?secret=\(initiation.secret)"), as: Status.self)

            if status.authenticated {
                let body = try JSONEncoder().encode(["Secret": initiation.secret])
                let result = try await send(request(baseURL, "/Users/AuthenticateWithQuickConnect", method: "POST", body: body), as: AuthenticationResult.self)
                return result.accessToken
            }
        }

        throw ActionError("Timed out waiting for the pairing code to be entered.")
    }
}

enum Keychain {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: Bundle.main.bundleIdentifier ?? "Jellyfin.Server",
        kSecAttrAccount as String: "QuickConnectToken",
    ]

    static var token: String? {
        get {
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query.merging([kSecReturnData as String: true]) { $1 } as CFDictionary, &item)

            guard status == errSecSuccess, let data = item as? Data else { return nil }

            return String(data: data, encoding: .utf8)
        }
        set {
            SecItemDelete(query as CFDictionary)

            if let token = newValue {
                SecItemAdd(query.merging([kSecValueData as String: Data(token.utf8)]) { $1 } as CFDictionary, nil)
            }
        }
    }
}
