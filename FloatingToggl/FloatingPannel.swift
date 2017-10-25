//
//  FloatingPannel.swift
//  FloatingToggl
//
//  Created by Zhigang Fang on 10/24/17.
//  Copyright © 2017 matrix. All rights reserved.
//

import Cocoa
import RxSwift

class FloatingPannel: NSWindowController {

    let disposebag = DisposeBag()

    override func windowDidLoad() {
        super.windowDidLoad()
        guard let panel = self.window as? NSPanel else {
            fatalError("Not loading")
        }
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseEntered(with: event)
    }

}
