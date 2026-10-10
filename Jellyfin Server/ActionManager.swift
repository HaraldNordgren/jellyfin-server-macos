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

    static func refreshLibraries(completion: @escaping (String?) -> Void) {
        let (port, proto, subPath) = getJellyfinNetworkConfig()

        var request = URLRequest(url: .init(string: "\(proto)://localhost:\(port)\(subPath)/LocalManagement/Library/Refresh")!)
        request.httpMethod = "POST"

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(error.localizedDescription)
            } else if let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) {
                completion(nil)
            } else if (response as? HTTPURLResponse)?.statusCode == 404 {
                completion("This version of Jellyfin Server does not support refreshing libraries from the menu bar.")
            } else {
                completion("The Jellyfin server did not accept the refresh request.")
            }
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
