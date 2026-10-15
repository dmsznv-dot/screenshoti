import CoreGraphics
import Testing
@testable import Screenshoti

struct PreviewLayoutTests {
    private let screen = CGRect(x: -1400, y: 70, width: 1200, height: 800)

    @Test(arguments: PreviewCorner.allCases)
    func stackGrowsFromChosenCorner(corner: PreviewCorner) throws {
        let layout = PreviewLayout(visibleFrame: screen, corner: corner, count: 3)
        let first = try #require(layout.frames.first)
        #expect(layout.frames.count == 3)
        #expect(screen.contains(first))
        if corner == .bottomLeft || corner == .topLeft {
            #expect(first.minX == screen.minX + 20)
        } else {
            #expect(first.maxX == screen.maxX - 20)
        }
        if corner == .bottomLeft || corner == .bottomRight {
            #expect(first.minY == screen.minY + 20)
            #expect(layout.frames[1].minY > first.maxY)
        } else {
            #expect(first.maxY == screen.maxY - 20)
            #expect(layout.frames[1].maxY < first.minY)
        }
    }

    @Test(arguments: PreviewCorner.allCases)
    func columnsAndOverflowKeepEveryCaptureReachable(corner: PreviewCorner) {
        var visited: Set<Int> = []
        let first = PreviewLayout(visibleFrame: screen, corner: corner, count: 40)
        #expect(first.pageCount > 1)
        for page in 0..<first.pageCount {
            let layout = PreviewLayout(visibleFrame: screen, corner: corner, count: 40, page: page)
            visited.formUnion(layout.visibleRange)
            #expect(layout.frames.count == layout.visibleRange.count)
            #expect(layout.frames.allSatisfy { screen.contains($0) })
            for (index, frame) in layout.frames.enumerated() {
                #expect(layout.frames.dropFirst(index + 1).allSatisfy { !frame.intersects($0) })
                if let navigation = layout.navigationFrame { #expect(!frame.intersects(navigation)) }
            }
            #expect(layout.navigationFrame.map { screen.contains($0) } == true)
        }
        #expect(visited == Set(0..<40))
    }

    @Test func smallScreenStillHasUsableCardsAndNavigation() {
        let small = CGRect(x: 400, y: -300, width: 320, height: 240)
        let layout = PreviewLayout(visibleFrame: small, corner: .bottomLeft, count: 20, page: 999)
        #expect(layout.frames.count == 1)
        #expect(layout.page == layout.pageCount - 1)
        #expect(layout.frames.allSatisfy { small.contains($0) && $0.width >= 240 && $0.height >= 120 })
        #expect(layout.navigationFrame.map { small.contains($0) } == true)
        #expect(layout.visibleRange == 19..<20)
    }

    @Test func emptyStackHasNoWindowsOrPages() {
        let layout = PreviewLayout(visibleFrame: screen, corner: .bottomLeft, count: 0)
        #expect(layout.frames.isEmpty && layout.visibleRange.isEmpty)
        #expect(layout.navigationFrame == nil && layout.pageCount == 0)
    }
}
