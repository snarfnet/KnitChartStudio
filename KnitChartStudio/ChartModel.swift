import Foundation

enum Stitch: String, Codable, CaseIterable, Identifiable {
    case empty, knit, purl, yarnOver, knitTwoTogether, slipSlipKnit
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .empty: return "·"
        case .knit: return "│"
        case .purl: return "—"
        case .yarnOver: return "○"
        case .knitTwoTogether: return "／"
        case .slipSlipKnit: return "＼"
        }
    }
    var name: String {
        switch self {
        case .empty: return "空白"
        case .knit: return "表目"
        case .purl: return "裏目"
        case .yarnOver: return "掛け目"
        case .knitTwoTogether: return "右上２目一度"
        case .slipSlipKnit: return "左上２目一度"
        }
    }
}

enum ChartPreset: String, CaseIterable, Identifiable {
    case stockinette, garter, moss, rib, checker, lace
    var id: String { rawValue }
    var name: String {
        switch self {
        case .stockinette: return "メリヤス風"
        case .garter: return "ガーター風"
        case .moss: return "鹿の子風"
        case .rib: return "２目ゴム編み風"
        case .checker: return "市松模様"
        case .lace: return "透かし模様"
        }
    }
}

struct KnitChart: Codable, Equatable {
    var version = 1
    var title = "新しい編み図"
    var rows = 16
    var columns = 16
    var stitches = Array(repeating: Stitch.empty, count: 256)
    var completedRows = 0
    var notes = ""
    var gaugeStitches = 20.0
    var gaugeRows = 28.0
    var yarnMetersPerSkein = 100.0
    var estimatedMeters = 0.0

    var isValid: Bool {
        version == 1 && (1...80).contains(rows) && (1...80).contains(columns) &&
        stitches.count == rows * columns && (0...rows).contains(completedRows) &&
        title.count <= 80 && notes.count <= 4000 && gaugeStitches.isFinite && gaugeRows.isFinite &&
        yarnMetersPerSkein.isFinite && estimatedMeters.isFinite &&
        (1...200).contains(gaugeStitches) && (1...200).contains(gaugeRows) &&
        (1...10000).contains(yarnMetersPerSkein) && (0...100000).contains(estimatedMeters)
    }

    subscript(row: Int, column: Int) -> Stitch {
        get { stitches[row * columns + column] }
        set { stitches[row * columns + column] = newValue }
    }

    mutating func resize(rows newRows: Int, columns newColumns: Int) {
        guard (1...80).contains(newRows), (1...80).contains(newColumns) else { return }
        var next = Array(repeating: Stitch.empty, count: newRows * newColumns)
        for row in 0..<min(rows, newRows) {
            for col in 0..<min(columns, newColumns) { next[row * newColumns + col] = self[row, col] }
        }
        rows = newRows; columns = newColumns; stitches = next
        completedRows = min(completedRows, newRows)
    }

    mutating func apply(_ preset: ChartPreset) {
        for row in 0..<rows { for col in 0..<columns {
            let stitch: Stitch
            switch preset {
            case .stockinette: stitch = .knit
            case .garter: stitch = row.isMultiple(of: 2) ? .knit : .purl
            case .moss: stitch = (row + col).isMultiple(of: 2) ? .knit : .purl
            case .rib: stitch = (col / 2).isMultiple(of: 2) ? .knit : .purl
            case .checker: stitch = (row / 4 + col / 4).isMultiple(of: 2) ? .knit : .purl
            case .lace:
                if row.isMultiple(of: 4) && col % 4 == 1 { stitch = .yarnOver }
                else if row.isMultiple(of: 4) && col % 4 == 2 { stitch = .knitTwoTogether }
                else { stitch = .knit }
            }
            self[row, col] = stitch
        } }
        completedRows = 0
    }

    /// Rows are stored bottom-up. Odd rows are read right-to-left on a flat chart.
    func instructions(row: Int) -> String {
        guard row >= 0 && row < rows else { return "" }
        let order = row.isMultiple(of: 2) ? Array((0..<columns).reversed()) : Array(0..<columns)
        let names = order.map { self[row, $0] }.filter { $0 != .empty }.map(\.name)
        return names.isEmpty ? "記号なし" : names.joined(separator: "、")
    }

    var estimatedWidthCM: Double { Double(columns) / gaugeStitches * 10 }
    var estimatedHeightCM: Double { Double(rows) / gaugeRows * 10 }
    var estimatedSkeins: Int { Int(ceil(estimatedMeters / yarnMetersPerSkein)) }
}
