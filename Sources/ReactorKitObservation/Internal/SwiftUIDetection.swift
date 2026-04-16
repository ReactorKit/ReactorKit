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
///
/// Cost profile:
///   - Initialization: one pass over loaded dylib images on first
///     call, parsing `AttributeGraph`'s mach-o segments into a range
///     set. Runs once per process, ~hundreds of microseconds.
///   - Per call: `Thread.callStackReturnAddresses` (single syscall +
///     frame pointer walk) + dictionary lookup in a cache keyed by
///     the stack hash. Repeated queries from the same call site hit
///     the cache and are O(1).
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@MainActor
public enum _SwiftUIRenderPathDetector {

  public static func isInRenderPath() -> Bool {
    let addresses = Thread.callStackReturnAddresses
    let key = addresses.hashValue
    if let cached = stackHashCache[key] { return cached }
    let result = addresses.reversed().contains { address in
      let value = UInt(bitPattern: address.pointerValue)
      return attributeGraphRanges.contains { $0.contains(value) }
    }
    stackHashCache[key] = result
    return result
  }

  /// Per-call-site cache of the render-path verdict, keyed by the
  /// hash of the return-address stack. SwiftUI hammers the same call
  /// sites, so nearly every query hits the cache.
  private static var stackHashCache = [Int: Bool]()

  /// Virtual-address ranges of every segment in the `AttributeGraph`
  /// dylib, adjusted for ASLR slide. Populated lazily on first
  /// access; empty when `AttributeGraph` isn't loaded.
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

      #if arch(x86_64) || arch(arm64)
      typealias _mach_header = mach_header_64
      typealias _segment_command = segment_command_64
      let LC_SEGMENT_KIND = UInt32(LC_SEGMENT_64)
      let header = headerPtr.withMemoryRebound(to: _mach_header.self, capacity: 1) { $0.pointee }
      #else
      typealias _mach_header = mach_header
      typealias _segment_command = segment_command
      let LC_SEGMENT_KIND = UInt32(LC_SEGMENT)
      let header = headerPtr.pointee
      #endif

      var commandPtr = UnsafeRawPointer(headerPtr).advanced(by: MemoryLayout<_mach_header>.size)
      for _ in 0..<header.ncmds {
        let cmd = commandPtr.load(as: load_command.self)
        if cmd.cmd == LC_SEGMENT_KIND {
          let segment = commandPtr.load(as: _segment_command.self)
          if segment.vmsize > 0 {
            let start = UInt(bitPattern: Int(segment.vmaddr) + slide)
            let end = UInt(bitPattern: Int(segment.vmaddr + segment.vmsize) + slide)
            ranges.append(start..<end)
          }
        }
        commandPtr = commandPtr.advanced(by: Int(cmd.cmdsize))
      }
      break
    }
    #endif
    return ranges
  }
}
#endif
