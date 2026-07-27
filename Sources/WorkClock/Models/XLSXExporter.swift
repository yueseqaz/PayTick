import Foundation

/// 生成真正的 .xlsx 文件（OOXML 格式），100% 复刻原 PHP 项目的导出样式：
/// - 标题合并 A1:E1
/// - 表头蓝底白字 #4472C4，加粗居中
/// - 上午/下午单元格按状态上色：work=#C6EFCE overtime=#FCE4D6 leave=#B4C6E7 rest=#E5E7EB other=#FFEB9C
/// - 周末（六+日）无记录时合并 C/D/E 列显示"周末休息"，灰底 #F3F4F6
/// - 底部统计汇总：出勤/加班/请假/其他 各几个"班"（半天数 / 2），按状态上色
/// - 列宽 A=15 B=10 C=12 D=12 E=30
/// - A2:E{last} 全表细边框
final class XLSXExporter {

    // MARK: - 颜色表（与 PHP export.php 完全一致）

    static let statusColors: [AttendanceStatus: String] = [
        .work: "C6EFCE",
        .overtime: "FCE4D6",
        .leave: "B4C6E7",
        .rest: "E5E7EB",
        .other: "FFEB9C"
    ]
    static let weekendMergedColor = "F3F4F6"
    static let headerBackgroundColor = "4472C4"

    // MARK: - Style 索引

    /// cellXfs 中的索引（顺序对应 buildStyles() 中的 <xf> 顺序）
    static let styleDefault = 0
    static let styleTitle = 1          // 标题：加粗 16pt 居中
    static let styleHeader = 2         // 表头：加粗白字 蓝底 居中 边框
    static let styleDataPlain = 3      // 普通数据单元格：边框
    static let styleStatsTitle = 4     // 统计汇总标题：加粗 12pt
    static let styleWeekendMerged = 5  // 周末合并块：灰底 居中 边框
    /// status → 状态色单元格 style index（在 buildStyles 末尾按 .allCases 顺序追加）
    static func styleForStatus(_ s: AttendanceStatus) -> Int {
        // 6 起按 AttendanceStatus.allCases 顺序：work/overtime/leave/rest/other
        let order = [AttendanceStatus.work, .overtime, .leave, .rest, .other]
        return 6 + (order.firstIndex(of: s) ?? 0)
    }

    // MARK: - 主入口

    /// 生成 .xlsx 到指定 URL（覆盖已存在文件）
    /// - Parameters:
    ///   - records: 全量记录（导出函数会自行按 range 过滤）
    ///   - rangeStart: 起始日期（包含）
    ///   - rangeEnd: 结束日期（包含）
    ///   - title: 表标题（如 "2026-07 考勤记录"）
    ///   - url: 目标文件路径
    /// - Returns: 成功与否
    static func export(
        records: [AttendanceRecord],
        rangeStart: Date,
        rangeEnd: Date,
        title: String,
        to url: URL
    ) -> Bool {
        let builder = SheetBuilder(records: records, rangeStart: rangeStart, rangeEnd: rangeEnd, title: title)
        builder.build()

        let fm = FileManager.default
        let tmpRoot = fm.temporaryDirectory.appendingPathComponent("PayTick_xlsx_\(UUID().uuidString)")
        do {
            try fm.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
            let dirs = ["_rels", "xl", "xl/_rels", "xl/worksheets"]
            for d in dirs {
                try fm.createDirectory(at: tmpRoot.appendingPathComponent(d), withIntermediateDirectories: true)
            }

            try builder.contentTypesXML.data(using: .utf8)?.write(to: tmpRoot.appendingPathComponent("[Content_Types].xml"))
            try builder.rootRelsXML.data(using: .utf8)?.write(to: tmpRoot.appendingPathComponent("_rels/.rels"))
            try builder.workbookXML.data(using: .utf8)?.write(to: tmpRoot.appendingPathComponent("xl/workbook.xml"))
            try builder.workbookRelsXML.data(using: .utf8)?.write(to: tmpRoot.appendingPathComponent("xl/_rels/workbook.xml.rels"))
            try builder.stylesXML.data(using: .utf8)?.write(to: tmpRoot.appendingPathComponent("xl/styles.xml"))
            try builder.sharedStringsXML.data(using: .utf8)?.write(to: tmpRoot.appendingPathComponent("xl/sharedStrings.xml"))
            try builder.sheetXML.data(using: .utf8)?.write(to: tmpRoot.appendingPathComponent("xl/worksheets/sheet1.xml"))
        } catch {
            try? fm.removeItem(at: tmpRoot)
            return false
        }

        // 用 zip -X 打包（-X 排除扩展属性，避免 macOS resource fork 污染）
        let success = zipDirectory(tmpRoot, to: url)
        try? fm.removeItem(at: tmpRoot)
        return success
    }

    // MARK: - zip

    private static func zipDirectory(_ dir: URL, to output: URL) -> Bool {
        // 删除已存在的输出文件
        try? FileManager.default.removeItem(at: output)

        let process = Process()
        process.launchPath = "/usr/bin/zip"
        process.arguments = [
            "-X", "-r", "-q",
            output.path,
            "."   // 打包当前目录所有文件（保留相对路径）
        ]
        process.currentDirectoryPath = dir.path
        // 静默 zip 的 stderr/stdout
        process.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - SheetBuilder

    /// 增量构建 sheet XML 与 shared strings
    private final class SheetBuilder {
        let records: [AttendanceRecord]
        let rangeStart: Date
        let rangeEnd: Date
        let title: String

        var sharedStrings: [String] = []
        var sharedStringsLookup: [String: Int] = [:]

        var rowsXML: [String] = []
        var mergeCells: [String] = []  // e.g. ["C3:D4", "C10:D11"]
        var lastRow: Int = 0

        init(records: [AttendanceRecord], rangeStart: Date, rangeEnd: Date, title: String) {
            self.records = records
            self.rangeStart = rangeStart
            self.rangeEnd = rangeEnd
            self.title = title
        }

        // MARK: 主流程

        func build() {
            // 1. 收集所有字符串
            let titleIdx = addString(title)
            let headerIdxs = ["日期", "星期", "上午", "下午", "备注"].map { addString($0) }
            let statsTitleIdx = addString("统计汇总")
            let statusNameIdx = [AttendanceStatus.work, .overtime, .leave, .rest, .other].map {
                addString($0.displayName)
            }
            let weekendRestIdx = addString("周末休息")
            _ = titleIdx; _ = statsTitleIdx; _ = weekendRestIdx

            // 2. 标题行（row 1, A1 merged to E1）
            rowsXML.append(rowXML(r: 1, cells: [
                cellXML(r: 1, c: 1, s: styleTitle, t: "s", v: titleIdx)
            ]))
            mergeCells.append("A1:E1")

            // 3. 表头行（row 2）
            var headerCells: [String] = []
            for (i, idx) in headerIdxs.enumerated() {
                headerCells.append(cellXML(r: 2, c: i + 1, s: styleHeader, t: "s", v: idx))
            }
            rowsXML.append(rowXML(r: 2, cells: headerCells))

            // 4. 数据行（row 3 起逐天填充）
            var row = 3
            let cal = Calendar.current

            // 按日期聚合记录
            var dailyData: [Date: [AttendancePeriod: AttendanceRecord]] = [:]
            for r in records {
                dailyData[r.recordDate, default: [:]][r.period] = r
            }

            // 用于合并周末块的跟踪
            var weekendStartRow: Int? = nil
            // 统计：work/overtime/leave/other 计数（rest 不计入"班"）
            var stats: [AttendanceStatus: Int] = [:]
            for s in [.work, .overtime, .leave, .other] as [AttendanceStatus] {
                stats[s] = 0
            }

            // 逐日遍历 rangeStart → rangeEnd
            var cursor = rangeStart
            while cursor <= rangeEnd {
                let weekday = cal.component(.weekday, from: cursor)  // 1=Sun ... 7=Sat
                let isWeekend = (weekday == 1 || weekday == 7)
                let dayRecords = dailyData[cursor] ?? [:]
                let hasRecord = !dayRecords.isEmpty

                // 日期字符串 YYYY-MM-DD
                let dateStr = dateString(cursor)
                let dateIdx = addString(dateStr)

                // 星期显示
                let weekDayName: String
                if let l = Locale(identifier: "zh_Hans") as Locale? {
                    let f = DateFormatter()
                    f.locale = l
                    f.dateFormat = "EEEE"
                    weekDayName = f.string(from: cursor)  // 星期日/星期一...
                } else {
                    weekDayName = "周\(weekdayChar(weekday))"
                }
                let weekIdx = addString(weekDayName)

                // 是否为"周末无记录"
                let showWeekendRest = isWeekend && !hasRecord

                if !showWeekendRest {
                    // 有记录或工作日：正常写入
                    var cells: [String] = []
                    cells.append(cellXML(r: row, c: 1, s: styleDataPlain, t: "s", v: dateIdx))
                    cells.append(cellXML(r: row, c: 2, s: styleDataPlain, t: "s", v: weekIdx))

                    // 上午
                    if let m = dayRecords[.morning] {
                        let sIdx = addString(m.status.displayName)
                        cells.append(cellXML(r: row, c: 3, s: styleForStatus(m.status), t: "s", v: sIdx))
                        if m.status != .rest { stats[m.status, default: 0] += 1 }
                    } else {
                        cells.append(cellXML(r: row, c: 3, s: styleDataPlain, t: "s", v: addString("")))
                    }
                    // 下午
                    if let a = dayRecords[.afternoon] {
                        let sIdx = addString(a.status.displayName)
                        cells.append(cellXML(r: row, c: 4, s: styleForStatus(a.status), t: "s", v: sIdx))
                        if a.status != .rest { stats[a.status, default: 0] += 1 }
                    } else {
                        cells.append(cellXML(r: row, c: 4, s: styleDataPlain, t: "s", v: addString("")))
                    }
                    // 备注：合并 morning/afternoon note
                    let note = mergedNote(morning: dayRecords[.morning]?.note, afternoon: dayRecords[.afternoon]?.note)
                    cells.append(cellXML(r: row, c: 5, s: styleDataPlain, t: "s", v: addString(note)))

                    rowsXML.append(rowXML(r: row, cells: cells))
                } else {
                    // 周末无记录：合并 Sat+Sun 的 C/D/E 列显示"周末休息"
                    if weekday == 7 {
                        // 周六：开始一个合并块
                        weekendStartRow = row
                        // 先写日期/星期占位（占位单元格正常输出）
                        let cells = [
                            cellXML(r: row, c: 1, s: styleDataPlain, t: "s", v: dateIdx),
                            cellXML(r: row, c: 2, s: styleDataPlain, t: "s", v: weekIdx),
                            cellXML(r: row, c: 3, s: styleWeekendMerged, t: "s", v: weekendRestIdx)
                            // D 和 E 列在 merge 后只写 A/B/C，D/E 留空但 range 仍需要
                        ]
                        rowsXML.append(rowXML(r: row, cells: cells))
                    } else if weekday == 1, let startRow = weekendStartRow {
                        // 周日：完成合并块
                        let cells = [
                            cellXML(r: row, c: 1, s: styleDataPlain, t: "s", v: dateIdx),
                            cellXML(r: row, c: 2, s: styleDataPlain, t: "s", v: weekIdx)
                            // C/D/E 由合并单元格覆盖
                        ]
                        rowsXML.append(rowXML(r: row, cells: cells))
                        // 合并 C-E 列从 startRow 到当前 row
                        mergeCells.append("C\(startRow):C\(row)")
                        mergeCells.append("D\(startRow):D\(row)")
                        mergeCells.append("E\(startRow):E\(row)")
                        weekendStartRow = nil
                    } else {
                        // 单独的周末天（理论上不会进这里）
                        let cells = [
                            cellXML(r: row, c: 1, s: styleDataPlain, t: "s", v: dateIdx),
                            cellXML(r: row, c: 2, s: styleDataPlain, t: "s", v: weekIdx)
                        ]
                        rowsXML.append(rowXML(r: row, cells: cells))
                    }
                }

                row += 1
                // 下一天
                cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }

            // 5. 统计汇总（空一行后）
            row += 2
            rowsXML.append(rowXML(r: row, cells: [
                cellXML(r: row, c: 1, s: styleStatsTitle, t: "s", v: addString("统计汇总"))
            ]))
            row += 1
            for s in [.work, .overtime, .leave, .other] as [AttendanceStatus] {
                let count = stats[s] ?? 0
                if count > 0 {
                    let shifts = Double(count) / 2.0
                    let shiftStr = String(format: "%.1f 班", shifts)
                    let cells = [
                        cellXML(r: row, c: 1, s: styleForStatus(s), t: "s", v: addString(s.displayName)),
                        cellXML(r: row, c: 2, s: styleDataPlain, t: "s", v: addString(shiftStr))
                    ]
                    rowsXML.append(rowXML(r: row, cells: cells))
                    row += 1
                }
            }
            lastRow = row - 1

            _ = statusNameIdx  // unused but kept for clarity
        }

        // MARK: - 输出 XML

        var contentTypesXML: String {
            """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
              <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
              <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
              <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
              <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
            </Types>
            """
        }

        var rootRelsXML: String {
            """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
            </Relationships>
            """
        }

        var workbookXML: String {
            """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
              <sheets>
                <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
              </sheets>
            </workbook>
            """
        }

        var workbookRelsXML: String {
            """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
              <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
              <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
            </Relationships>
            """
        }

        var stylesXML: String {
            // fonts: 0=default 1=title(bold 16) 2=header(bold white) 3=statsTitle(bold 12)
            // fills: 0=none 1=gray125(required) 2=header blue 3..7=work/overtime/leave/rest/other 8=weekend merged
            // borders: 0=none 1=thin all
            // cellXfs: 见 styleXxx 常量
            let statusFills = [AttendanceStatus.work, .overtime, .leave, .rest, .other]
                .map { statusColorRGB($0) }
                .enumerated()
                .map { idx, rgb in
                    "<fill><patternFill patternType=\"solid\"><fgColor rgb=\"FF\(rgb)\"/><bgColor rgb=\"FF\(rgb)\"/></patternFill></fill>"
                }.joined()

            let statusXfs = [AttendanceStatus.work, .overtime, .leave, .rest, .other]
                .enumerated()
                .map { idx, _ in
                    // styleForStatus = 6 + idx → fillId = 3 + idx
                    let fillId = 3 + idx
                    return "<xf numFmtId=\"0\" fontId=\"0\" fillId=\"\(fillId)\" borderId=\"1\" xfId=\"0\" applyFill=\"1\" applyBorder=\"1\"/>"
                }.joined()

            return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <fonts count="4">
                <font><sz val="11"/><name val="Helvetica"/></font>
                <font><b/><sz val="16"/><name val="Helvetica"/></font>
                <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Helvetica"/></font>
                <font><b/><sz val="12"/><name val="Helvetica"/></font>
              </fonts>
              <fills count="9">
                <fill><patternFill patternType="none"/></fill>
                <fill><patternFill patternType="gray125"/></fill>
                <fill><patternFill patternType="solid"><fgColor rgb="FF\(XLSXExporter.headerBackgroundColor)"/><bgColor rgb="FF\(XLSXExporter.headerBackgroundColor)"/></patternFill></fill>
                \(statusFills)
                <fill><patternFill patternType="solid"><fgColor rgb="FF\(XLSXExporter.weekendMergedColor)"/><bgColor rgb="FF\(XLSXExporter.weekendMergedColor)"/></patternFill></fill>
              </fills>
              <borders count="2">
                <border><left/><right/><top/><bottom/><diagonal/></border>
                <border>
                  <left style="thin"><color rgb="FF000000"/></left>
                  <right style="thin"><color rgb="FF000000"/></right>
                  <top style="thin"><color rgb="FF000000"/></top>
                  <bottom style="thin"><color rgb="FF000000"/></bottom>
                  <diagonal/>
                </border>
              </borders>
              <cellStyleXfs count="1">
                <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
              </cellStyleXfs>
              <cellXfs count="\(6 + 5)">
                <!-- 0: default -->
                <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
                <!-- 1: title -->
                <xf numFmtId="0" fontId="1" fillId="0" borderId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
                <!-- 2: header -->
                <xf numFmtId="0" fontId="2" fillId="2" borderId="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
                <!-- 3: data plain -->
                <xf numFmtId="0" fontId="0" fillId="0" borderId="1" applyBorder="1"/>
                <!-- 4: stats title -->
                <xf numFmtId="0" fontId="3" fillId="0" borderId="0" applyFont="1"/>
                <!-- 5: weekend merged -->
                <xf numFmtId="0" fontId="0" fillId="8" borderId="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
                \(statusXfs)
              </cellXfs>
            </styleSheet>
            """
        }

        var sharedStringsXML: String {
            let items = sharedStrings.map { "<si><t>\(escapeXML($0))</t></si>" }.joined()
            return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(sharedStrings.count)" uniqueCount="\(sharedStrings.count)">
            \(items)
            </sst>
            """
        }

        var sheetXML: String {
            let mergeCount = mergeCells.count
            let mergeXML = mergeCount > 0
                ? "<mergeCells count=\"\(mergeCount)\">\(mergeCells.map { "<mergeCell ref=\"\($0)\"/>" }.joined())</mergeCells>"
                : ""

            return """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
              <cols>
                <col min="1" max="1" width="15" customWidth="1"/>
                <col min="2" max="2" width="10" customWidth="1"/>
                <col min="3" max="3" width="12" customWidth="1"/>
                <col min="4" max="4" width="12" customWidth="1"/>
                <col min="5" max="5" width="30" customWidth="1"/>
              </cols>
              <sheetData>
            \(rowsXML.joined(separator: "\n"))
              </sheetData>
            \(mergeXML)
              <pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>
            </worksheet>
            """
        }

        // MARK: - Helpers

        @discardableResult
        func addString(_ s: String) -> Int {
            if let idx = sharedStringsLookup[s] { return idx }
            let idx = sharedStrings.count
            sharedStrings.append(s)
            sharedStringsLookup[s] = idx
            return idx
        }

        func cellXML(r: Int, c: Int, s: Int, t: String, v: Int) -> String {
            "<c r=\"\(colLetter(c))\(r)\" s=\"\(s)\" t=\"\(t)\"><v>\(v)</v></c>"
        }

        func rowXML(r: Int, cells: [String]) -> String {
            "<row r=\"\(r)\">\(cells.joined())</row>"
        }

        func colLetter(_ n: Int) -> String {
            // 1 → A, 2 → B, ..., 26 → Z, 27 → AA
            var n = n
            var s = ""
            while n > 0 {
                n -= 1
                s = String(UnicodeScalar(0x41 + n % 26)!) + s
                n /= 26
            }
            return s
        }

        func dateString(_ d: Date) -> String {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: d)
        }

        func weekdayChar(_ weekday: Int) -> String {
            // weekday: 1=Sun...7=Sat
            let chars = ["日", "一", "二", "三", "四", "五", "六"]
            return chars[weekday - 1]
        }

        func mergedNote(morning: String?, afternoon: String?) -> String {
            let m = morning ?? ""
            let a = afternoon ?? ""
            if !m.isEmpty && !a.isEmpty { return "早: \(m) | 午: \(a)" }
            if !m.isEmpty { return m }
            if !a.isEmpty { return a }
            return ""
        }

        func statusColorRGB(_ s: AttendanceStatus) -> String {
            XLSXExporter.statusColors[s] ?? "FFFFFF"
        }

        func escapeXML(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
             .replacingOccurrences(of: "\"", with: "&quot;")
        }
    }
}
