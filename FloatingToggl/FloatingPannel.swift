//
//  FloatingPannel.swift
//  FloatingToggl
//
//  Created by Zhigang Fang on 10/24/17.
//  Copyright © 2017 matrix. All rights reserved.
//

import Cocoa

class FloatingPannel: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()

        if let panel = self.window as? NSPanel {
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isFloatingPanel = true
        }

    }

}
