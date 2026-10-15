import Foundation

enum PreviewCorner: String, CaseIterable, Identifiable, Codable {
    case bottomLeft, bottomRight, topLeft, topRight

    var id: String { rawValue }
    var isLeft: Bool { self == .bottomLeft || self == .topLeft }
    var isBottom: Bool { self == .bottomLeft || self == .bottomRight }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .bottomLeft: return language == .ru ? "Снизу слева" : "Bottom left"
        case .bottomRight: return language == .ru ? "Снизу справа" : "Bottom right"
        case .topLeft: return language == .ru ? "Сверху слева" : "Top left"
        case .topRight: return language == .ru ? "Сверху справа" : "Top right"
        }
    }
}

/// A bounded grid of previews. Overflow is paged, so every retained image remains reachable.
struct PreviewLayout {
    let frames: [CGRect]
    let visibleRange: Range<Int>
    let navigationFrame: CGRect?
    let page: Int
    let pageCount: Int

    init(visibleFrame: CGRect, corner: PreviewCorner, count: Int, page requestedPage: Int = 0) {
        guard count > 0, visibleFrame.width > 0, visibleFrame.height > 0 else {
            frames = []; visibleRange = 0..<0; navigationFrame = nil; page = 0; pageCount = 0
            return
        }
        let margin = min(20, min(visibleFrame.width, visibleFrame.height) / 20)
        let bounds = visibleFrame.insetBy(dx: margin, dy: margin)
        let gap: CGFloat = 10
        let width = min(280, bounds.width)
        let fullHeight = min(190, bounds.height)
        let columns = max(1, Int((bounds.width + gap) / (width + gap)))
        let initialRows = max(1, Int((bounds.height + gap) / (fullHeight + gap)))
        let hasOverflow = count > columns * initialRows
        let navigationHeight = hasOverflow ? min(32, bounds.height / 4) : 0
        let navigationSpace = hasOverflow ? navigationHeight + gap : 0
        let height = min(190, max(1, bounds.height - navigationSpace))
        let rows = max(1, Int((bounds.height - navigationSpace + gap) / (height + gap)))
        let capacity = rows * columns
        pageCount = (count + capacity - 1) / capacity
        page = min(max(0, requestedPage), pageCount - 1)
        let start = page * capacity
        visibleRange = start..<min(count, start + capacity)

        // Navigation sits on the edge opposite the selected corner.
        if hasOverflow {
            navigationFrame = CGRect(
                x: corner.isLeft ? bounds.minX : bounds.maxX - width,
                y: corner.isBottom ? bounds.maxY - navigationHeight : bounds.minY,
                width: width, height: navigationHeight
            )
        } else {
            navigationFrame = nil
        }
        frames = visibleRange.enumerated().map { position, _ in
            let column = position / rows, row = position % rows
            return CGRect(
                x: corner.isLeft ? bounds.minX + CGFloat(column) * (width + gap)
                    : bounds.maxX - width - CGFloat(column) * (width + gap),
                y: corner.isBottom ? bounds.minY + CGFloat(row) * (height + gap)
                    : bounds.maxY - height - CGFloat(row) * (height + gap),
                width: width, height: height
            )
        }
    }
}
