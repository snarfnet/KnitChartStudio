import UIKit

enum ChartPDF {
    static func make(_ chart: KnitChart) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { pdf in
            let tile = 20
            for rowBlock in stride(from: 0, to: chart.rows, by: tile) {
                for colBlock in stride(from: 0, to: chart.columns, by: tile) {
                    pdf.beginPage()
                    let head: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
                    let text: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9)]
                    (chart.title as NSString).draw(at: CGPoint(x: 35, y: 28), withAttributes: head)
                    ("段 \(rowBlock + 1)–\(min(rowBlock + tile, chart.rows)) / 目 \(colBlock + 1)–\(min(colBlock + tile, chart.columns))" as NSString).draw(at: CGPoint(x: 35, y: 58), withAttributes: text)
                    let cell: CGFloat = 25, x0: CGFloat = 48, y0: CGFloat = 90
                    let top = min(rowBlock + tile, chart.rows)
                    for row in rowBlock..<top {
                        let y = y0 + CGFloat(top - 1 - row) * cell
                        ("\(row + 1)" as NSString).draw(at: CGPoint(x: 25, y: y + 6), withAttributes: text)
                        for col in colBlock..<min(colBlock + tile, chart.columns) {
                            let x = x0 + CGFloat(col - colBlock) * cell
                            let rect = CGRect(x: x, y: y, width: cell, height: cell)
                            UIColor.lightGray.setStroke(); UIBezierPath(rect: rect).stroke()
                            let symbol = chart[row, col].symbol as NSString
                            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 16)]
                            let size = symbol.size(withAttributes: attrs)
                            symbol.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attrs)
                        }
                    }
                    let legend = Stitch.allCases.filter { $0 != .empty }.map { "\($0.symbol) \($0.name)" }.joined(separator: "    ")
                    (legend as NSString).draw(in: CGRect(x: 35, y: 620, width: 525, height: 65), withAttributes: text)
                    ("１段目は右から。記号の表裏変換や増減後の目数は確認してください。" as NSString).draw(in: CGRect(x: 35, y: 700, width: 525, height: 40), withAttributes: text)
                }
            }
        }
    }
}
