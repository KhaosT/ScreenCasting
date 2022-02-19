//
//  WindowController.swift
//  ScreenCasting
//
//  Created by Khaos Tian on 6/6/19.
//  Copyright © 2019 Oltica. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.appearance = NSAppearance(named: .darkAqua)
        window?.backgroundColor = .black
        window?.isMovableByWindowBackground = true
    }
}
