//
//  SwiftUIDetection.swift
//  ReactorKitObservation
//
//  Created by Kanghoon Oh on 4/13/26.
//

#if DEBUG
import Foundation
#if canImport(MachO)
import MachO
#endif

/// Detects whether the current call stack is inside a SwiftUI view
/// body, by scanning `Thread.callStackReturnAddresses` for frames in
/// the `AttributeGraph` dylib — SwiftUI's render engine. Used by
/// the DEBUG-only missing-scope warning in ``ObservedReactor`` to
/// distinguish reads made during SwiftUI view body evaluation from
/// reads made in arbitrary contexts (Rx pipelines, tests, `init`, …).
///
/// Fails open: if `AttributeGraph` can't be located — Apple renamed
/// it, statically linked it, or the binary runs outside SwiftUI
/// entirely — the cached ranges stay empty, every query returns
/// `false`, and the warning silently turns off. No crashes, no
/// false positives.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@MainActor
public struct _SwiftUIRenderPathDetector {

  public init() {}

  public mutating func isInRenderPath() -> Bool {
    let addresses = Thread.callStackReturnAddresses
    let key = addresses.hashValue
    if let cached = stackHashCache[key] { return cached }
    let result = addresses.reversed().contains { address in
      let value = UInt(bitPattern: address.pointerValue)
      return Self.attributeGraphRanges.contains { $0.contains(value) }
    }
    stackHashCache[key] = result
    return result
  }

  /// Per-call-site cache of the render-path verdict, keyed by the
  /// hash of the return-address stack. Instance-scoped so the cache
  /// lifetime matches the owning `ObservedReactor` — dismissed
  /// screens free their entries instead of accumulating process-wide.
  private var stackHashCache = [Int: Bool]()

  /// Virtual-address ranges of every segment in the `AttributeGraph`
  /// dylib, adjusted for ASLR slide. Populated lazily on first
  /// access; empty when `AttributeGraph` isn't loaded. Process-wide
  /// constant post-load, so kept `static` and shared across detectors.
  private static let attributeGraphRanges: [Range<UInt>] = collectAttributeGraphRanges()

  private static func collectAttributeGraphRanges() -> [Range<UInt>] {
    var ranges = [Range<UInt>]()
    #if canImport(MachO)
    let imageCount = _dyld_image_count()
    for i in 0..<imageCount {
      guard let cName = _dyld_get_image_name(i) else { continue }
      let name = String(cString: cName)
      guard name.hasSuffix("/AttributeGraph") else { continue }
      guard let headerPtr = _dyld_get_image_header(i) else { continue }
      let slide = _dyld_get_image_vmaddr_slide(i)

      let header = UnsafeRawPointer(headerPtr).load(as: NativeMachHeader.self)
      var commandPtr = UnsafeRawPointer(headerPtr).advanced(by: MemoryLayout<NativeMachHeader>.size)
      for _ in 0..<header.ncmds {
        let cmd = commandPtr.load(as: load_command.self)
        if cmd.cmd == nativeSegmentLoadCommand,
           let range = commandPtr.load(as: NativeSegmentCommand.self).addressRange(slide: slide) {
          ranges.append(range)
        }
        commandPtr = commandPtr.advanced(by: Int(cmd.cmdsize))
      }
      break
    }
    #endif
    return ranges
  }
}

#if canImport(MachO)
#if arch(x86_64) || arch(arm64)
private typealias NativeMachHeader = mach_header_64
typealias NativeSegmentCommand = segment_command_64
private let nativeSegmentLoadCommand = UInt32(LC_SEGMENT_64)
#else
private typealias NativeMachHeader = mach_header
typealias NativeSegmentCommand = segment_command
private let nativeSegmentLoadCommand = UInt32(LC_SEGMENT)
#endif

extension NativeSegmentCommand {
  /// Runtime address range of this segment, or `nil` when it is empty
  /// or would wrap past the top of the address space.
  ///
  /// Stays in `UInt` with wrapping arithmetic: `vmaddr` can exceed
  /// `Int.max` (e.g. on arm64_32, where it is a 32-bit `UInt32`), so
  /// converting it to `Int` traps. `UInt(vmaddr)` itself never traps
  /// because the native segment fields are pointer-width.
  func addressRange(slide: Int) -> Range<UInt>? {
    guard vmsize > 0 else { return nil }
    let start = UInt(vmaddr) &+ UInt(bitPattern: slide)
    let (end, overflow) = start.addingReportingOverflow(UInt(vmsize))
    guard !overflow else { return nil }
    return start..<end
  }
}
#endif
#endif
