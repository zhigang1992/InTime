//
//  AppDelegate.swift
//  FloatingToggl
//
//  Created by Zhigang Fang on 10/24/17.
//  Copyright © 2017 matrix. All rights reserved.
//

import Cocoa
import KeychainSwift

extension UserDefaults {

    var reminderInterval: Int {
        get { return UserDefaults.standard.integer(forKey: "com.floatingtoggl.reminder") }
        set { UserDefaults.standard.set(newValue, forKey: "com.floatingtoggl.reminder") }
    }

    var shouldAutoApply: Bool {
        get { return UserDefaults.standard.bool(forKey: "com.floatingtoggl.autoapply") }
        set { UserDefaults.standard.set(newValue, forKey: "com.floatingtoggl.autoapply") }
    }

}

extension Notification.Name {

    static let reminderIntervalUpdated: Notification.Name = Notification.Name("com.floatingtoggl.reminderintervalupdated")

}


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var reminderInterval: Int = 0 {
        didSet {
            fiveMinuteReminder.isChecked = reminderInterval == 5
            thirtyMinuteReminder.isChecked = reminderInterval == 30
            noReminder.isChecked = reminderInterval == 0
            if reminderInterval != oldValue {
                UserDefaults.standard.reminderInterval = reminderInterval
                NotificationCenter.default.post(name: .reminderIntervalUpdated, object: nil)
            }
        }
    }

    @IBOutlet weak var fiveMinuteReminder: NSMenuItem!
    @IBOutlet weak var thirtyMinuteReminder: NSMenuItem!
    @IBOutlet weak var noReminder: NSMenuItem!

    @IBAction func reminder5minTapped(_ sender: NSMenuItem) {
        reminderInterval = 5
    }

    @IBAction func reminder30minTapped(_ sender: NSMenuItem) {
        reminderInterval = 30
    }

    @IBAction func reminderNoneTapped(_ sender: NSMenuItem) {
        reminderInterval = 0
    }

    var shouldAutoApply: Bool = false {
        didSet {
            autoApply.isChecked = shouldAutoApply
            if shouldAutoApply != oldValue {
                UserDefaults.standard.shouldAutoApply = shouldAutoApply
            }
        }
    }
    @IBOutlet weak var autoApply: NSMenuItem!
    @IBAction func autoApplyTapped(_ sender: NSMenuItem) {
        shouldAutoApply = !shouldAutoApply
    }


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application

        reminderInterval = UserDefaults.standard.reminderInterval
        shouldAutoApply = UserDefaults.standard.shouldAutoApply

    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}


extension NSMenuItem {

    var isChecked: Bool {
        get { return state ~= .on }
        set { state = newValue ? .on : .off }
    }

}
