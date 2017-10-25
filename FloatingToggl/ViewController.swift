//
//  ViewController.swift
//  FloatingToggl
//
//  Created by Zhigang Fang on 10/24/17.
//  Copyright © 2017 matrix. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxCocoa
import KeychainSwift

struct TimeEntry: Decodable {
    let id: Int64
    let start: String
    let description: String?
}

struct DataResponse<T: Decodable>: Decodable {
    let data: T
}

struct Project: Decodable {
    let id: Int64
    let name: String
}

struct User: Decodable {

    let id: Int64
    let fullname: String
    let projects: [Project]
    let time_entries: [TimeEntry]

}

private extension URL {

    static func api(_ path: String) -> URL {
        return URL(string: "https://www.toggl.com/api/v8/\(path)")!
    }

}

struct Endpoint<T: Decodable> {
    let method: String
    let url: URL

    func request(with token: String) -> Observable<T> {
        return Observable.deferred({ () -> Observable<T> in
            let base64 = "\(token):api_token".data(using: .utf8)!.base64EncodedString()
            var request = URLRequest(url: URL(string: "https://www.toggl.com/api/v8/me?with_related_data=true")!)
            request.addValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            request.httpMethod = self.method
            return URLSession.shared.rx.data(request: request).map({ data in
                (try JSONDecoder().decode(DataResponse<T>.self, from: data)).data
            })
        })
    }

    static var me: Endpoint<User> { return Endpoint<User>(method: "GET", url: URL.api("me?with_related_data=true")) }
    static var currentEntry: Endpoint<Optional<TimeEntry>> { return Endpoint<Optional<TimeEntry>>(method: "GET", url: URL.api("time_entries/current")) }
}


class TogglViewModel {

    private let keychain = KeychainSwift()

    let token: Variable<String?>

    let refresh = PublishSubject<Void>()
    let current = Variable<TimeEntry?>(nil)
    let user = Variable<User?>(nil)

    let input = Variable<String>("")

    private let disposeBag = DisposeBag()

    var completions: Driver<[String]> {
        return user.asDriver().map({ user -> [String] in
            guard let user = user else { return [] }
            let projects = user.projects.map({"#\($0.name)"})
            let entries = user.time_entries.sorted(by: {$0.start > $1.start}).flatMap({$0.description})
            return Array(NSOrderedSet(array: projects + entries)).flatMap({$0 as? String})
        }).flatMapLatest({[weak self] (completion:[String]) -> Driver<[String]> in
            guard let input = self?.input else { return .just(completion) }
            return input.asDriver().map({ input in
                if input.isEmpty { return completion }
                let predicate = NSPredicate(format: "SELF contains[c] %@", input)
                return completion.filter({$0 != input && predicate.evaluate(with: $0 as NSString)})
            })
        })
    }

    init() {
        let tokenKey = "com.floatToggl.tokenKey"
        token = Variable(keychain.get(tokenKey))
        token.asDriver().skip(1).drive(onNext: {[weak self] t in
            if let t = t {
                self?.keychain.set(t, forKey: tokenKey)
            } else {
                self?.keychain.delete(tokenKey)
            }
        }).disposed(by: self.disposeBag)
        token.asDriver().flatMapLatest({ token -> Driver<TimeEntry?> in
            if let token = token {
                return self.refresh.asDriver(onErrorJustReturn: ()).startWith(()).flatMapLatest({_ in
                    Endpoint<TimeEntry?>.currentEntry
                        .request(with: token)
                        .asDriver(onErrorJustReturn: nil)
                })
            }
            return Driver<TimeEntry?>.just(nil)
        }).debug().drive(current).disposed(by: self.disposeBag)

        token.asDriver().flatMapLatest({ token -> Driver<User?> in
            if let token = token {
                return Endpoint<User>.me.request(with: token).map(Optional.some).asDriver(onErrorJustReturn: nil)
            }
            return Driver<User?>.just(nil)
        }).debug().drive(user).disposed(by: self.disposeBag)
    }

}


class ViewController: NSViewController {

    let viewModel = TogglViewModel()

    fileprivate let disposeBag = DisposeBag()

    @IBOutlet weak var inputLabel: NSTextField!

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
        tableView.doubleAction = #selector(self.insertSelection)
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

    var recentItems: [String] = [] {
        didSet {
            if inputLabel.stringValue.isEmpty { return }
            self.isShowingRecentEntries = !recentItems.isEmpty
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.timerLabel.isHidden = true
        self.actionButton.isHidden = true
        setupUI()

        viewModel.completions.drive(onNext: {[weak self] completions in
            guard let `self` = self else { return }
            self.recentItems = completions
            let numberOfRows = min(completions.count, 8)
            let size = CGSize(
                width: self.view.bounds.width,
                height: CGFloat(numberOfRows) * (self.tableView.rowHeight + self.tableView.intercellSpacing.height)
            )
            self.recentItemVC.contentSize = size
            self.tableView.reloadData()
            self.selectedRow = 0
        }).disposed(by: self.disposeBag)
    }

    var isShowingRecentEntries: Bool {
        get {
            return recentItemVC.isShown
        }
        set {
            guard newValue != isShowingRecentEntries else { return }

            if newValue {
                guard !recentItems.isEmpty else { return }
                recentItemVC.show(relativeTo: .zero, of: self.view, preferredEdge: .minY)
                self.selectedRow = 0
            } else {
                recentItemVC.close()
            }
        }
    }

    @IBAction func presentRecentEntries(_ sender: NSMenuItem) {
        self.isShowingRecentEntries = !self.isShowingRecentEntries
    }

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
        alert.beginSheetModal(for: NSApplication.shared.keyWindow!) {[weak self] (response) in
            guard response == .alertFirstButtonReturn else { return }
            self?.viewModel.token.value = tokenField.stringValue
        }
        tokenField.becomeFirstResponder()
    }


    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    var selectedRow: Int {
        get {
            return tableView.selectedRow
        }
        set {
            let index: Int
            if newValue < 0 {
                index = tableView.numberOfRows - 1
            } else if newValue >= tableView.numberOfRows {
                index = 0
            } else {
                index = newValue
            }
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            tableView.scrollRowToVisible(index)
        }
    }

}

extension ViewController: NSTextFieldDelegate {

    @objc func insertSelection() {
        guard isShowingRecentEntries else { return }

        inputLabel.stringValue = recentItems[self.selectedRow]
        viewModel.input.value = recentItems[self.selectedRow]
        isShowingRecentEntries = false
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(textView.cancelOperation(_:)):
            isShowingRecentEntries = !isShowingRecentEntries
        case #selector(textView.moveUp(_:)), #selector(textView.insertBacktab(_:)):
            selectedRow = selectedRow - 1
            isShowingRecentEntries = true
        case #selector(textView.moveDown(_:)):
            selectedRow = selectedRow + 1
            isShowingRecentEntries = true
        case #selector(textView.insertTab(_:)):
            if recentItems.count > 1 {
                selectedRow = selectedRow + 1
                isShowingRecentEntries = true
            } else if recentItems.count == 1 {
                insertSelection()
            }
        case #selector(textView.insertNewline(_:)):
            insertSelection()
        default:
            return false
        }
        return true
    }

    override func controlTextDidChange(_ obj: Notification) {
        self.viewModel.input.value = inputLabel.stringValue
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
            let c = NSColor.selectedMenuItemColor
            c.setFill()
            self.bounds.fill()
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
