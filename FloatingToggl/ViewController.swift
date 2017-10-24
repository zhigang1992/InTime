//
//  ViewController.swift
//  FloatingToggl
//
//  Created by Zhigang Fang on 10/24/17.
//  Copyright © 2017 matrix. All rights reserved.
//

import Foundation
import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var inputLabel: NSTextFieldCell!

    @IBOutlet weak var timerLabel: NSTextField!

    @IBOutlet weak var actionButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.timerLabel.isHidden = true
        self.actionButton.isHidden = true
        setupUI()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

extension ViewController: NSTextFieldDelegate {

    func control(_ control: NSControl, textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
        return words
    }

//    override func controlTextDidChange(_ obj: Notification) {
//        guard let fieldEditor = obj.userInfo?["NSFieldEditor"] as? NSTextView else { return }
////        fieldEditor.complete(nil)
//    }

}


private extension ViewController {

    func setupUI() {
        inputLabel.focusRingType = .none
        inputLabel.placeholderAttributedString = NSAttributedString(
            string: inputLabel.placeholderString ?? "",
            attributes: [
                .foregroundColor: NSColor(white: 1, alpha: 0.4),
                .font: NSFont.systemFont(ofSize: 15)
            ])
    }

}
