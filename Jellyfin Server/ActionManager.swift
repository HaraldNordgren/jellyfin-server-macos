//
// Jellyfin Server is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2022 Jellyfin & Jellyfin Contributors
//

import AppKit
import Foundation

enum ActionManager {
    static func launchWebUI() {
        let (port, proto, subPath) = getJellyfinNetworkConfig()
        NSWorkspace.shared.open(.init(string: "\(proto)://localhost:\(port)\(subPath)")!)
    }

    /// Triggers a library scan with the token from Quick Connect, pairing first if there is no valid token yet.
    static func refreshLibraries(onPairingCode: (String) -> Void) async throws {
        let (port, proto, subPath) = getJellyfinNetworkConfig()
        let baseURL = "\(proto)://localhost:\(port)\(subPath)"

        if let token = Keychain.token, try await postLibraryRefresh(baseURL, token: token) {
            return
        }

        Keychain.token = nil

        let token = try await QuickConnect.pair(baseURL: baseURL, onCode: onPairingCode)

        guard try await postLibraryRefresh(baseURL, token: token) else {
            throw ActionError("The user who entered the pairing code must be an administrator.")
        }

        Keychain.token = token
    }

    private static func postLibraryRefresh(_ baseURL: String, token: String) async throws -> Bool {
        var request = URLRequest(url: .init(string: "\(baseURL)/Library/Refresh")!)
        request.httpMethod = "POST"
        request.setValue(QuickConnect.authorizationHeader(token: token), forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        switch (response as? HTTPURLResponse)?.statusCode {
        case .some(200 ... 299):
            return true
        case 401, 403:
            return false
        default:
            throw ActionError("The Jellyfin server did not accept the refresh request.")
        }
    }

    static func showLogs() {
        let logFolder = directoryExists(path: localShareJellyfinFolder.path) ? localShareJellyfinFolder.appendingPathComponent("/log") : applicationSupportJellyfinFolder.appendingPathComponent("/log")
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logFolder.path)
    }

    static func launchAbout() {
        NSWorkspace.shared.open(.init(string: "https://jellyfin.org")!)
    }

    static func restart() {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 2; open \"\(Bundle.main.bundlePath)\""]
        task.launch()

        NSApp.terminate(self)
        exit(0)
    }

    static func terminateWithError() {
        NSApp.terminate(self)
        exit(1)
    }
}
