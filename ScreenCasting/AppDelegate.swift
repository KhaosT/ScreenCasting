//
//  AppDelegate.swift
//  ScreenCasting
//
//  Created by Khaos Tian on 6/6/19.
//  Copyright © 2019 Oltica. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var primaryWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        primaryWindow = NSApplication.shared.windows.first
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else {
            return false
        }
        
        primaryWindow?.makeKeyAndOrderFront(self)
        return true
    }
}

