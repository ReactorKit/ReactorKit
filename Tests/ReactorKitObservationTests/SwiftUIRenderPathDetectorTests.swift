//
//  SwiftUIRenderPathDetectorTests.swift
//  ReactorKitObservationTests
//
//  Created by Kanghoon Oh on 11/26/26.
//

#if DEBUG && canImport(MachO)
import MachO
import XCTest

@testable import ReactorKitObservation

final class SwiftUIRenderPathDetectorTests: XCTestCase {

  /// A `vmaddr` above `Int.max` used to trap in `Int(segment.vmaddr)`.
  /// On arm64_32 that happens for any 32-bit address above `Int32.max`;
  /// this reproduces the same condition at the host's pointer width.
  func testAddressRangeAboveIntMax() {
    let vmaddr = UInt(Int.max) + 1
    let range = segment(vmaddr: vmaddr, vmsize: 0x1000).addressRange(slide: 0x4000)
    XCTAssertEqual(range, (vmaddr + 0x4000)..<(vmaddr + 0x5000))
  }

  func testAddressRangeAppliesSlide() {
    let range = segment(vmaddr: 0x1_0000, vmsize: 0x100).addressRange(slide: 0x20)
    XCTAssertEqual(range, 0x1_0020..<0x1_0120)
  }

  func testAddressRangeAppliesNegativeSlide() {
    let range = segment(vmaddr: 0x1_0000, vmsize: 0x100).addressRange(slide: -0x20)
    XCTAssertEqual(range, 0xFFE0..<0x1_00E0)
  }

  func testAddressRangeOfEmptySegmentIsNil() {
    XCTAssertNil(segment(vmaddr: 0x1_0000, vmsize: 0).addressRange(slide: 0))
  }

  func testAddressRangeWrappingPastTopIsNil() {
    XCTAssertNil(segment(vmaddr: UInt.max - 0xF, vmsize: 0x100).addressRange(slide: 0))
  }

  private func segment(vmaddr: UInt, vmsize: UInt) -> NativeSegmentCommand {
    var segment = NativeSegmentCommand()
    segment.vmaddr = .init(vmaddr)
    segment.vmsize = .init(vmsize)
    return segment
  }
}
#endif
