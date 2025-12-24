//
//  AppDelegate.swift
//  MetalRacingGame
//
//  Application delegate
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Application setup
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Cleanup
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

