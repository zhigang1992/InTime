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

    lazy var tableView: NSTableView = {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        column.isEditable = false
        column.width = 500
        let tableView = NSTableView()
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.rowSizeStyle = .small
        tableView.intercellSpacing = NSSize(width: 20, height: 3)
        tableView.headerView = nil
        tableView.refusesFirstResponder = true
        tableView.target = self
        tableView.addTableColumn(column)
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()

    lazy var recentItemVC: NSPopover = {
        let sv = NSScrollView()
        sv.drawsBackground = false
        sv.hasVerticalScroller = true
        sv.documentView = self.tableView

        let vc = NSViewController()
        vc.view = NSView()
        vc.view.addSubview(sv)
        sv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: vc.view.topAnchor),
            sv.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            sv.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
        ])

        let po = NSPopover()
        po.appearance = NSAppearance(named: .vibrantLight)
        po.animates = false
        po.contentViewController = vc
        return po
    }()

    var recentItems: [String] = ["Hello", "world", "This is a test","Hello", "world", "This is a test","Hello", "world", "This is a test","Hello", "world", "This is a test","Hello", "world", "This is a test","Hello", "world", "This is a test",]

    override func viewDidLoad() {
        super.viewDidLoad()
        self.timerLabel.isHidden = true
        self.actionButton.isHidden = true
        setupUI()
    }

    @IBAction func presentRecentEntries(_ sender: NSMenuItem) {
        recentItemVC.contentSize = CGSize(width: self.view.bounds.width, height: 100)
        recentItemVC.show(relativeTo: .zero, of: self.view, preferredEdge: .minY)
        self.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

extension ViewController: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return recentItems.count
    }

    private static let identity = NSUserInterfaceItemIdentifier(rawValue: "Cell")

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView: NSTableCellView = tableView.makeView(withIdentifier: ViewController.identity, owner: self) as? NSTableCellView ?? {
            let cell = NSTableCellView()
            let textField = NSTextField()
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.isSelectable = false
            cell.addSubview(textField)
            cell.textField = textField
            cell.identifier = ViewController.identity
            return cell
        }()
        cellView.textField?.attributedStringValue = NSAttributedString(
            string: self.recentItems[row],
            attributes: [
                NSAttributedStringKey.foregroundColor: NSColor.black
            ])
        return cellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return HighlightRow()
    }
}

class HighlightRow: NSTableRowView {

    override func drawSelection(in dirtyRect: NSRect) {
        if self.selectionHighlightStyle != .none {
            let selectBound = self.bounds.insetBy(dx: 0.5, dy: 0.5)
            let c = NSColor.selectedMenuItemColor
            c.setStroke()
            c.setFill()
            let path = NSBezierPath(roundedRect: selectBound, xRadius: 0, yRadius: 0)
            path.stroke()
            path.fill()
        }
    }

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        return isSelected ? .dark : .light
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
