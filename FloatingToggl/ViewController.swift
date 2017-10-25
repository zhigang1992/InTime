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
    let body: NSDictionary?

    init(method: String = "GET", url: URL, body: NSDictionary? = nil) {
        self.method = method
        self.url = url
        self.body = body
    }

    func request(with token: String) -> Observable<T> {
        return Observable.deferred({ () -> Observable<T> in
            let base64 = "\(token):api_token".data(using: .utf8)!.base64EncodedString()
            var request = URLRequest(url: self.url)
            request.addValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpMethod = self.method
            if let body = self.body {
                request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
            }
            return URLSession.shared.rx.data(request: request).map({ data in
                (try JSONDecoder().decode(DataResponse<T>.self, from: data)).data
            })
        })
    }

    static var me: Endpoint<User> { return Endpoint<User>(url: URL.api("me?with_related_data=true")) }

    static var currentEntry: Endpoint<Optional<TimeEntry>> { return Endpoint<Optional<TimeEntry>>(url: URL.api("time_entries/current")) }

    static func start(title: String, projectId: Int64?) -> Endpoint<TimeEntry> {
        return Endpoint<TimeEntry>(method: "POST", url: URL.api("time_entries/start"), body: [
            "time_entry": [
                "description": title,
                "pid": projectId ?? NSNull(),
                "created_with": "Toggl Bar"
            ] as NSDictionary
        ])
    }

    static func stop(timeEntry: Int64) -> Endpoint<TimeEntry> {
        return Endpoint<TimeEntry>(method: "PUT", url: URL.api("time_entries/\(timeEntry)/stop"))
    }

}


class TogglViewModel {

    private let keychain = KeychainSwift()

    let token: Variable<String?>

    let refresh = PublishSubject<Void>()
    let current = Variable<TimeEntry?>(nil)
    let user = Variable<User?>(nil)

    let input = Variable<String>("")

    let active = Variable<Bool>(NSApplication.shared.isActive)

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
        }).debounce(0.2)
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

        Observable.merge([
            NotificationCenter.default.rx
                .notification(NSApplication.didBecomeActiveNotification)
                .map({_ in true}),
            NotificationCenter.default.rx
                .notification(NSApplication.willResignActiveNotification)
                .map({_ in false})
        ]).bind(to: self.active).disposed(by: self.disposeBag)

        self.active.asDriver()
            .distinctUntilChanged()
            .filter({$0})
            .map({_ in ()})
            .drive(refresh)
            .disposed(by: self.disposeBag)

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

        token.asDriver().flatMapLatest({[weak self] token -> Driver<User?> in
            if let token = token {
                return self?.current.asDriver().flatMapLatest({ _ in
                    Endpoint<User>.me.request(with: token).map(Optional.some).asDriver(onErrorJustReturn: nil)
                }) ?? .just(nil)
            }
            return Driver<User?>.just(nil)
        }).debug().drive(user).disposed(by: self.disposeBag)
    }

    func startTimer() {
        guard let token = self.token.value else { return }
        let projectId = self.input.value.hashKey.flatMap({ projectName in
            self.user.value?.projects.first(where: {
                $0.name.lowercased() == projectName.lowercased()
            })
        })?.id
        Endpoint<TimeEntry>.start(title: self.input.value, projectId: projectId)
            .request(with: token)
            .map(Optional.some)
            .catchErrorJustReturn(nil)
            .bind(to: current)
            .disposed(by: self.disposeBag)
    }

    func stopTimer() {
        guard let token = self.token.value else { return }
        guard let entryId = self.current.value?.id else { return }
        Endpoint<TimeEntry>.stop(timeEntry: entryId).request(with: token)
            .map({_ in nil})
            .catchErrorJustReturn(nil)
            .bind(to: current)
            .disposed(by: self.disposeBag)
    }

}

class AutoGrowTextField: NSTextField {

    override var intrinsicContentSize: NSSize {
        self.isEditable = false
        defer {
            self.isEditable = true
        }
        return super.intrinsicContentSize
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
            self.tableView.reloadData()
            let numberOfRows = min(recentItems.count, 8)
            let size = CGSize(
                width: self.view.bounds.width,
                height: CGFloat(numberOfRows) * (self.tableView.rowHeight + self.tableView.intercellSpacing.height)
            )
            self.recentItemVC.contentSize = size
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
            self.selectedRow = 0
        }).disposed(by: self.disposeBag)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"

        viewModel.current.asDriver().flatMapLatest({ entry -> Driver<String> in
            guard let start = entry?.start, let date = df.date(from: start) else { return .empty() }
            return Driver<Int>.interval(1).startWith(1).map({ _ in
                let time: Int = Int(Date().timeIntervalSince(date))
                let hours = time / 3600
                let minutes = (time / 60) % 60
                let seconds = time % 60
                return String(format: "%0.2d:%0.2d:%0.2d", hours, minutes, seconds)
            })
        }).drive(onNext: {[weak self] text in
            self?.timerLabel.stringValue = text
        }).disposed(by: self.disposeBag)

        viewModel.current.asDriver().drive(onNext: {[weak self] current in
            self?.timerLabel.isHidden = current == nil
            self?.actionButton.isHidden = current == nil
            if let current = current {
                let text = current.description ?? "Untitled"
                self?.inputLabel.stringValue = text
                self?.viewModel.input.value = text
                self?.isShowingRecentEntries = false
                self?.inputLabel.window?.makeFirstResponder(nil)
            } else {
                self?.inputLabel.stringValue = ""
                self?.viewModel.input.value = ""
            }
            self?.placeCursorAtTheEnd()
            self?.resizeWindow()
        }).disposed(by: self.disposeBag)
    }

    var trackingRect: NSView.TrackingRectTag?
    override func viewDidLayout() {
        super.viewDidLayout()
        if let t = trackingRect {
            view.removeTrackingRect(t)
        }
        trackingRect = view.addTrackingRect(view.bounds, owner: self, userData: nil, assumeInside: false)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if viewModel.token.value == nil {
            self.presentSetToken()
        }
    }

    var isShowingRecentEntries: Bool {
        get {
            return recentItemVC.isShown
        }
        set {
            guard newValue != isShowingRecentEntries else { return }

            if newValue {
                guard !recentItems.isEmpty else { return }
                guard inputLabel.currentEditor()?.selectedRange.length == 0 else { return }

                recentItemVC.show(relativeTo: .zero, of: self.view, preferredEdge: .minY)
            } else {
                recentItemVC.close()
            }
        }
    }

    func resizeWindow() {
        guard let window = self.view.window else { return }
        let minSize = self.view.fittingSize
        window.setFrame(NSRect(origin: window.frame.origin, size: minSize), display: true)
    }


    @IBAction func presentRecentEntries(_ sender: NSMenuItem) {
        self.isShowingRecentEntries = !self.isShowingRecentEntries
    }

    @IBAction func stopTimer(_ sender: NSButton) {
        self.viewModel.stopTimer()
    }

    func placeCursorAtTheEnd() {
        guard let editor = self.inputLabel.currentEditor() else { return }

        let string = self.inputLabel.stringValue as NSString
        editor.selectedRange = NSRange(location: string.length, length: 0)
    }

    func presentSetToken() {
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

    @IBAction func setToken(_ sender: NSMenuItem) {
        presentSetToken()
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
            if tableView.numberOfRows == 0 { return }
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
        self.placeCursorAtTheEnd()
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
            insertSelection()
        case #selector(textView.insertNewline(_:)):
            self.viewModel.startTimer()
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
            textField.usesSingleLineMode = true
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

private extension String {

    var hashKey: String? {
        do {
            let regex = try NSRegularExpression(pattern: "#([^ ]+)( |$)", options: [])
            let ns = (self as NSString)
            return regex.matches(in: self, options: [], range: NSRange(location: 0, length: ns.length))
                .first
                .flatMap({ result in
                    guard result.numberOfRanges > 1 else { return nil }
                    return ns.substring(with: result.range(at: 1))
                })
        } catch {
            return nil
        }
    }

}
