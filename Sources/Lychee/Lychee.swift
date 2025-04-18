// The Swift Programming Language
// https://docs.swift.org/swift-book

import LycheeObjC

public enum PSXButton : UInt32 {
    case select   = 0x01
    case l3       = 0x02
    case r3       = 0x04
    case start    = 0x08
    case up       = 0x10
    case right    = 0x20
    case down     = 0x40
    case left     = 0x80
    case l2       = 0x100
    case r2       = 0x200
    case l1       = 0x400
    case r1       = 0x800
    case triangle = 0x1000
    case circle   = 0x2000
    case cross    = 0x4000
    case square   = 0x8000
    case analog   = 0x10000
}

public typealias BufferHandler = (UnsafeMutableRawPointer, UInt32, UInt32, UInt32, UInt32) -> Void
public typealias BGR555Handler = BufferHandler
public typealias RGB888Handler = BufferHandler

public struct Lychee : @unchecked Sendable {
    public static let shared = Lychee()
    
    public let emulator = LycheeObjC.shared()
    
    public func insert(from url: URL) { emulator.insert(from: url) }
    
    public func step() { emulator.step() }
    public func stop() { emulator.stop() }
    
    public func bgr555(_ buffer: @escaping BGR555Handler) { emulator.bgr555 = buffer }
    public func rgb888(_ buffer: @escaping RGB888Handler) { emulator.rgb888 = buffer }
    
    public func input(_ slot: Int, _ button: PSXButton, _ pressed: Bool) {
        emulator.input(.init(slot), button: button.rawValue, pressed: pressed)
    }
    
    public func id(from url: URL) -> String {
        emulator.id(from: url)
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: ".", with: "")
    }
}
