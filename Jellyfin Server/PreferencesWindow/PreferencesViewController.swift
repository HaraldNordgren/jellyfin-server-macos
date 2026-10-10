//
// Jellyfin Server is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2022 Jellyfin & Jellyfin Contributors
//

import AppKit

class PreferencesViewController: NSViewController {
    @IBOutlet var versionLabel: NSTextField!
    @objc dynamic var launchAtLogin = LanchAtLoginHelper.kvo
    @IBOutlet var copyrightLabel: NSTextField!
    @IBOutlet var apiKeyField: NSSecureTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionLabel.stringValue = "Version \(appVersion ?? "0.0.1")"

        let copyright = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
        copyrightLabel.stringValue = copyright ?? ""

        apiKeyField.stringValue = UserDefaults.standard.string(forKey: apiKeyDefaultsKey) ?? ""
    }

    @IBAction func apiKeyChanged(_ sender: NSTextField) {
        UserDefaults.standard.set(sender.stringValue, forKey: apiKeyDefaultsKey)
    }

    @IBAction func launchWebUISelected(_: Any) {
        ActionManager.launchWebUI()
    }

    @IBAction func showLogsSelected(_: Any) {
        ActionManager.showLogs()
    }

    @IBAction func aboutSelected(_: Any) {
        ActionManager.launchAbout()
    }
}
