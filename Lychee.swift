//
//  Lychee.swift
//  Lychee
//
//  Created by Jarrod Norwell on 2/9/2026.
//

import Foundation

public enum LycheeButton : UInt32 {
    case a = 0x1
    case b = 0x2
    case select = 0x4
    case start = 0x8
    case right = 0x10
    case left = 0x20
    case up = 0x40
    case down = 0x80
    case r = 0x100
    case l = 0x200
    case x = 0x400
    case y = 0x800
    
    var uint32: UInt32 { rawValue }
}

public class LycheeCommon {
    public init() {}
    
    public static var documentDirectoryURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    public static var lycheeDirectoryURL: String? {
        if let documentDirectoryURL {
            documentDirectoryURL.appending(component: "Lychee").path
        } else {
            nil
        }
    }
}

public actor LycheeSystem {
    private var fileManager: FileManager = .default
    
    public init() {}
    
    public func printAbout() {
        lychee.print_about()
    }
    
    public func initializePaths() {
        lychee.initialize_paths()
    }
    
    public func initializeSystem() {
        lychee.initialize_system()
    }
    
    public func destroySystem() {
        lychee.destroy_system()
    }
    
    public func insertDisc(at url: URL) {
        lychee.insert_disc(std.string(url.path))
    }
    
    public func set(change: Bool = false, isRunning: Bool = false) {
        if change {
            running = isRunning
        }
    }
    
    public var running: Bool {
        get {
            lychee.is_running()
        }
        set {
            lychee.is_running(true, newValue)
        }
    }
    
    public func set(change: Bool = false, isPaused: Bool = false) {
        if change {
            paused = isPaused
        }
    }
    
    public var paused: Bool {
        get {
            lychee.is_paused()
        }
        set {
            lychee.is_paused(true, newValue)
        }
    }
    
    
    public func start() {
        lychee.start()
    }
    
    public func stop() {
        lychee.stop()
    }
    
    
    public var framebufferHeight: Int32 {
        lychee.framebuffer_height()
    }
    
    public var framebufferWidth: Int32 {
        lychee.framebuffer_width()
    }
    
    
    public nonisolated func press(button: LycheeButton) {
        lychee.press_button(button.uint32)
    }
    
    public nonisolated func release(button: LycheeButton) {
        lychee.release_button(button.uint32)
    }
    
    
    public nonisolated func audioBuffer(callback: lychee.AudioVideoBufferCallback) {
        lychee.audio_buffer_callback(callback)
    }
    
    public nonisolated func videoBuffer(callback: lychee.AudioVideoBufferCallback) {
        lychee.video_buffer_callback(callback)
    }
    
    
    public func setContext(context: UnsafeMutableRawPointer) {
        lychee.set_context(context)
    }
    
    
    public nonisolated func boxartURLString(for url: URL) -> String? {
        let title: String = url.deletingPathExtension().lastPathComponent
        
        return "https://raw.githubusercontent.com/libretro/libretro-thumbnails/refs/heads/master/Nintendo - Super Nintendo Entertainment System/Named_Boxarts/\(title).png"
    }
}
