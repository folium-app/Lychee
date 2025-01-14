// The Swift Programming Language
// https://docs.swift.org/swift-book

import LycheeObjC

public enum PSXButton : UInt32 {
    case select = 0x00000001
    case l3 = 0x00000002
    case r3 = 0x00000004
    case start = 0x00000008
    case dpadUp = 0x00000010
    case dpadRight = 0x00000020
    case dpadDown = 0x00000040
    case dpadLeft = 0x00000080
    case l2 = 0x00000100
    case r2 = 0x00000200
    case l1 = 0x00000400
    case r1 = 0x00000800
    case triangle = 0x00001000
    case circle = 0x00002000
    case cross = 0x00004000
    case square = 0x00008000
    // case ANALOG = 0x00010000
}

public struct Lychee : @unchecked Sendable {
    public static let shared = Lychee()
    
    public let lycheeObjC = LycheeObjC.shared()
    
    public func insertCartridge(from url: URL) {
        lycheeObjC.insertCartridge(url)
    }
    
    public func step() {
        lycheeObjC.step()
    }
    
    public func stop() {
        lycheeObjC.stop()
    }
    
    public func bufferBGR555(_ buf: @escaping (UnsafeMutablePointer<UInt16>, UInt32, UInt32) -> Void) {
        lycheeObjC.bufferBGR555 = buf
    }
    
    public func bufferRGB24(_ buf: @escaping (UnsafeMutablePointer<UInt32>, UInt32, UInt32) -> Void) {
        lycheeObjC.bufferRGB24 = buf
    }
    
    public func input(_ slot: Int, _ button: PSXButton, _ pressed: Bool) {
        lycheeObjC.input(Int32(slot), button: button.rawValue, pressed: pressed)
    }
    
    public func gameID(from url: URL) -> String {
        lycheeObjC.gameID(url)
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: ".", with: "")
    }
}
