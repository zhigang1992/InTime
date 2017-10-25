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

    var tableView: NSTableView {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        column.isEditable = false
        column.width = 500
        let tableView = NSTableView()
        tableView.selectionHighlightStyle = .regular
        tableView.rowSizeStyle = .small
        tableView.intercellSpacing = NSSize(width: 20, height: 3)
        tableView.headerView = nil
        tableView.refusesFirstResponder = true
        tableView.target = self
        return tableView
    }

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
