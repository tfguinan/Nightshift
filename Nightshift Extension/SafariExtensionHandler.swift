//
//  SafariExtensionHandler.swift
//  Nightshift Extension
//
//  Created by Леша Маслаков on 3/23/20.
//  Copyright © 2020 Леша Маслаков.
//  Copyright © 2021-2022 Jahn Bertsch.
//

import SafariServices

@available(macOSApplicationExtension 10.12, *)
class SafariExtensionHandler: SFSafariExtensionHandler {
    private static var excluded: [String] = UserDefaults.standard.array(forKey: "excluded") as? [String] ?? [] {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(excluded, forKey: "excluded")
            defaults.synchronize()
        }
    }

    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        switch messageName {
        case "nightshift":
            page.getPropertiesWithCompletionHandler { properties in
                if let host = userInfo?["host"] as? String, host != "" {
                    self.dispatchMessage(page: page, host: host, darkMode: !self.isHostExcluded(host))
                }
            }
        default:
            break
        }
    }

    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        let enabled = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        validationHandler(enabled, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }

    override func popoverWillShow(in window: SFSafariWindow) {
        window.getActiveTab { tab in
            tab?.getActivePage { page in
                page?.getPropertiesWithCompletionHandler { properties in
                    /* update has to be done on the main thread
                       https://stackoverflow.com/a/60144786/11717191 */
                    DispatchQueue.main.async {
                        if let url = properties?.url, let hostname = url.host {
                            let host = ((url.port) != nil) ? "\(hostname):\(url.port!)" : hostname
                            SafariExtensionViewController.shared.host = host
                            SafariExtensionViewController.shared.darkMode = !self.isHostExcluded(host)
                            SafariExtensionViewController.shared.onDarkModeOn = { () -> Void in
                                self.removeHostFromExcluded(host)
                                self.dispatchMessage(page: page, host: host, darkMode: true)
                            }
                            SafariExtensionViewController.shared.onDarkModeOff = { () -> Void in
                                self.addHostToExcluded(host)
                                self.dispatchMessage(page: page, host: host, darkMode: false)
                            }
                            SafariExtensionViewController.shared.onReload = { () -> Void in
                                page?.dispatchMessageToScript(
                                    withName: "nightshift-reload"
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    override func popoverDidClose(in window: SFSafariWindow) {
        SafariExtensionViewController.shared.host = nil
        SafariExtensionViewController.shared.onDarkModeOn = nil
        SafariExtensionViewController.shared.onDarkModeOff = nil
        SafariExtensionViewController.shared.onReload = nil
    }

    private func dispatchMessage(page: SFSafariPage?, host: String, darkMode: Bool) {
        guard host != "" else {
            return
        }
        
        page?.dispatchMessageToScript(
            withName: "nightshift",
            userInfo: [
                "darkmode": darkMode,
                "host": host as Any,
            ]
        )
    }

    private func addHostToExcluded(_ host: String) {
        if !isHostExcluded(host) {
            Self.excluded.append(host)
        }
    }

    private func removeHostFromExcluded(_ host: String) {
        if isHostExcluded(host) {
            Self.excluded.removeAll(where: { $0 == host} )
        }
    }

    private func isHostExcluded(_ host: String) -> Bool {
        return Self.excluded.contains(host)
    }
}
