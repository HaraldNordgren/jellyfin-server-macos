//
// Jellyfin Server is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2022 Jellyfin & Jellyfin Contributors
//

import AppKit
import Foundation

enum RefreshLibrariesError: LocalizedError {
    case invalidURL
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not build a request URL for the Jellyfin server."
        case .unexpectedResponse:
            return "The Jellyfin server did not accept the refresh request."
        }
    }
}

enum ActionManager {
    static func launchWebUI() {
        let (port, proto, subPath) = getJellyfinNetworkConfig()
        NSWorkspace.shared.open(.init(string: "\(proto)://localhost:\(port)\(subPath)")!)
    }

    static func refreshLibraries(completion: @escaping (Error?) -> Void) {
        let (port, proto, subPath) = getJellyfinNetworkConfig()

        guard let url = URL(string: "\(proto)://localhost:\(port)\(subPath)/Library/Refresh") else {
            completion(RefreshLibrariesError.invalidURL)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
                completion(RefreshLibrariesError.unexpectedResponse)
                return
            }

            completion(nil)
        }.resume()
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
