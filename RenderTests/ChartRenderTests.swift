import XCTest
import PDFKit
@testable import KnitChartStudio

final class ChartRenderTests: XCTestCase {
    @MainActor func testMultiPagePDFAndRoundTrip() throws {
        var chart = KnitChart()
        chart.resize(rows: 41, columns: 41)
        chart[0, 0] = .knit
        chart[40, 40] = .yarnOver
        let encoded = try JSONEncoder().encode(chart)
        let decoded = try JSONDecoder().decode(KnitChart.self, from: encoded)
        XCTAssertEqual(decoded, chart)
        let data = ChartPDF.make(decoded)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 9)
        XCTAssertEqual(document.page(at: 0)?.bounds(for: .mediaBox).width ?? 0, 595, accuracy: 0.1)
        try data.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("knit-chart-test.pdf"))
    }
}
