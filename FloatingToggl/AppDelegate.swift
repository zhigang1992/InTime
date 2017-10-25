//
//  AppDelegate.swift
//  FloatingToggl
//
//  Created by Zhigang Fang on 10/24/17.
//  Copyright © 2017 matrix. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBAction func setToken(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Toggl API Token:\nhttps://toggl.com/app/profile"

        let tokenField = NSTextField()
        tokenField.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        tokenField.usesSingleLineMode = true

        alert.accessoryView = tokenField
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: NSApplication.shared.keyWindow!) { (response) in
            guard response == .alertFirstButtonReturn else { return }
            print(tokenField.stringValue)
        }
        tokenField.becomeFirstResponder()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

