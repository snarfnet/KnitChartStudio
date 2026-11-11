import SwiftUI
import UniformTypeIdentifiers
import UIKit

@MainActor final class ChartStore: ObservableObject {
    @Published var chart = KnitChart()
    @Published var error: String?
    @Published var history: [KnitChart] = []
    private var blocked = false
    private let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("KnitChartStudio/chart.json")
    init() {
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            let data = try Data(contentsOf: file)
            let loaded = try JSONDecoder().decode(KnitChart.self, from: data)
            guard loaded.isValid else { throw CocoaError(.fileReadCorruptFile) }
            chart = loaded
        } catch {
            blocked = true
            self.error = "保存データを読み込めません。元のファイルは保護しています。"
        }
    }
    func change(_ update: (inout KnitChart) -> Void) {
        guard !blocked else { error = "保存データを保護しているため編集できません。"; return }
        var next = chart; update(&next)
        guard next.isValid, next != chart else { return }
        history.append(chart); if history.count > 50 { history.removeFirst() }
        chart = next; save()
    }
    func undo() { guard !blocked, let previous = history.popLast() else { return }; chart = previous; save() }
    func replace(_ data: Data) throws {
        guard !blocked, data.count <= 1_000_000 else { throw CocoaError(.fileReadCorruptFile) }
        let incoming = try JSONDecoder().decode(KnitChart.self, from: data)
        guard incoming.isValid else { throw CocoaError(.fileReadCorruptFile) }
        history.append(chart); if history.count > 50 { history.removeFirst() }
        chart = incoming; save()
    }
    private func save() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(chart).write(to: file, options: .atomic)
        } catch { self.error = "保存できませんでした。空き容量を確認してください。" }
    }
}

@main struct KnitChartStudioApp: App {
    @StateObject private var store = ChartStore()
    var body: some Scene { WindowGroup { ContentView().environmentObject(store) } }
}

struct ExportItem: Identifiable { let id = UUID(); let url: URL }
struct ContentView: View {
    @EnvironmentObject var store: ChartStore
    @State private var tool: Stitch = .knit
    @State private var tab = 0
    @State private var importing = false
    @State private var showResize = false
    @State private var newRows = 16
    @State private var newColumns = 16
    @State private var exported: ExportItem?
    private let ink = Color(red: 0.23, green: 0.25, blue: 0.22)
    private let accent = Color(red: 0.50, green: 0.29, blue: 0.24)
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("画面", selection: $tab) { Text("編み図").tag(0); Text("段と記録").tag(1); Text("寸法・糸").tag(2) }
                    .pickerStyle(.segmented).padding()
                if tab == 0 { editor } else if tab == 1 { instructions } else { calculations }
            }
            .background(Color(red: 0.97, green: 0.96, blue: 0.93))
            .navigationTitle("編み図工房")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(store.history.isEmpty).accessibilityLabel("元に戻す") }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu { Button("作品ファイルを読み込む") { importing = true }; Button("作品をJSONで保存") { exportJSON() }; Button("編み図をPDFで保存") { exportPDF() } } label: { Image(systemName: "square.and.arrow.up") }
                }
            }
            .tint(accent)
            .sheet(item: $exported) { ShareView(url: $0.url) }
            .sheet(isPresented: $showResize) {
                NavigationStack { Form { Stepper("段数：\(newRows)", value: $newRows, in: 1...80); Stepper("目数：\(newColumns)", value: $newColumns, in: 1...80); Text("小さくすると範囲外の記号が消えます。元に戻すで復元できます。") }.navigationTitle("編み図の大きさ").toolbar { ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { showResize = false } }; ToolbarItem(placement: .confirmationAction) { Button("変更") { store.change { $0.resize(rows: newRows, columns: newColumns) }; showResize = false } } } }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do { let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; try store.replace(Data(contentsOf: url)) }
                catch { store.error = "作品ファイルを読み込めませんでした。現在の作品はそのままです。" }
            }
            .alert("保存・読み込み", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("閉じる") { store.error = nil } } message: { Text(store.error ?? "") }
        }
    }
    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { TextField("作品名", text: Binding(get: { store.chart.title }, set: { v in store.change { $0.title = String(v.prefix(80)) } })).font(.headline); Button("大きさ") { newRows = store.chart.rows; newColumns = store.chart.columns; showResize = true } }.padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(Stitch.allCases) { stitch in Button { tool = stitch } label: { VStack { Text(stitch.symbol).font(.title2); Text(stitch.name).font(.caption2) }.frame(width: 76, height: 52).background(tool == stitch ? accent.opacity(0.2) : .white, in: RoundedRectangle(cornerRadius: 8)) }.accessibilityLabel(stitch.name) } }.padding(.horizontal) }
            Text("記号を選び、マスをタップ。１段目は右から読みます。") .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(spacing: 1) {
                    ForEach(Array((0..<store.chart.rows).reversed()), id: \.self) { row in
                        HStack(spacing: 1) {
                            Text("\(row + 1)").font(.caption2).frame(width: 28)
                            ForEach(0..<store.chart.columns, id: \.self) { col in
                                Button { store.change { $0[row, col] = tool } } label: { Text(store.chart[row, col].symbol).font(.system(size: 20)).foregroundStyle(ink).frame(width: 32, height: 32).background(row < store.chart.completedRows ? Color.green.opacity(0.16) : .white) }.buttonStyle(.plain).accessibilityLabel("\(row + 1)段 \(col + 1)目 \(store.chart[row, col].name)")
                            }
                        }
                    }
                }.padding(12)
            }.background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
        }.padding(.bottom)
    }
    private var instructions: some View {
        List {
            Section("進み具合") {
                HStack { Button("−") { store.change { $0.completedRows = max(0, $0.completedRows - 1) } }; Spacer(); Text("\(store.chart.completedRows) / \(store.chart.rows) 段完了").monospacedDigit(); Spacer(); Button("＋") { store.change { $0.completedRows = min($0.rows, $0.completedRows + 1) } } }
                Text("手順は配置した記号の一覧です。裏側から見た記号の変換や増減後の目数は自動判定しません。") .font(.caption).foregroundStyle(.secondary)
            }
            Section("段ごとの記号") { ForEach(0..<store.chart.rows, id: \.self) { row in VStack(alignment: .leading) { Text("\(row + 1)段目").font(.headline); Text(store.chart.instructions(row: row)).font(.caption) } } }
            Section("メモ") { TextField("糸や針、作り方のメモ", text: Binding(get: { store.chart.notes }, set: { v in store.change { $0.notes = String(v.prefix(4000)) } }), axis: .vertical).lineLimit(3...8) }
        }
    }
    private var calculations: some View {
        Form {
            Section("10cmあたりのゲージ") {
                Stepper("目数：\(store.chart.gaugeStitches.formatted())", value: Binding(get: { store.chart.gaugeStitches }, set: { v in store.change { $0.gaugeStitches = v } }), in: 1...200, step: 0.5)
                Stepper("段数：\(store.chart.gaugeRows.formatted())", value: Binding(get: { store.chart.gaugeRows }, set: { v in store.change { $0.gaugeRows = v } }), in: 1...200, step: 0.5)
                Text(String(format: "推定寸法 %.1f × %.1f cm", store.chart.estimatedWidthCM, store.chart.estimatedHeightCM))
                Text("長方形の目安です。模様や増減、糸の伸びは反映しません。") .font(.caption).foregroundStyle(.secondary)
            }
            Section("毛糸の目安") {
                Stepper("１玉の長さ：\(Int(store.chart.yarnMetersPerSkein)) m", value: Binding(get: { store.chart.yarnMetersPerSkein }, set: { v in store.change { $0.yarnMetersPerSkein = v } }), in: 1...10000, step: 10)
                Stepper("必要な長さ：\(Int(store.chart.estimatedMeters)) m", value: Binding(get: { store.chart.estimatedMeters }, set: { v in store.change { $0.estimatedMeters = v } }), in: 0...100000, step: 10)
                Text("必要な玉数：\(store.chart.estimatedSkeins) 玉")
                Text("必要な長さはご自身で入力してください。") .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func write(_ data: Data, ext: String) { do { let url = FileManager.default.temporaryDirectory.appendingPathComponent("knit-chart-\(UUID()).\(ext)"); try data.write(to: url, options: .atomic); exported = ExportItem(url: url) } catch { store.error = "書き出せませんでした。" } }
    private func exportJSON() { do { write(try JSONEncoder().encode(store.chart), ext: "json") } catch { store.error = "書き出せませんでした。" } }
    private func exportPDF() { write(ChartPDF.make(store.chart), ext: "pdf") }
}

struct ShareView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
