import Foundation
var chart = KnitChart()
precondition(chart.isValid)
chart[0,0] = .knit; chart[0,15] = .purl
precondition(chart.instructions(row:0) == "裏目、表目")
chart.resize(rows:20, columns:20)
precondition(chart[0,0] == .knit && chart[0,15] == .purl && chart.isValid)
chart.completedRows = 20
chart.resize(rows:8, columns:8)
precondition(chart.completedRows == 8 && chart[0,0] == .knit && chart.isValid)
let copy = try JSONDecoder().decode(KnitChart.self, from: JSONEncoder().encode(chart))
precondition(copy == chart)
var bad = copy; bad.stitches = []; precondition(!bad.isValid)
print("Chart resizing, ordering, validation and persistence passed")
