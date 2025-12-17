//
//  MarkdownBlock.swift
//  pods
//
//  Created by Dimi Nunez on 12/17/25.
//


//
//  MarkdownParser.swift
//  pods
//
//  Created by Claude on 12/17/25.
//

import SwiftUI

// MARK: - Markdown Block Types

struct MarkdownBlock: Identifiable {
    let id = UUID()
    let type: BlockType

    enum BlockType {
        case paragraph(AttributedString)
        case header(level: Int, text: AttributedString)
        case codeBlock(language: String?, code: String)
        case table(headers: [String], rows: [[String]])
        case bulletList(items: [AttributedString])
        case numberedList(items: [AttributedString])
        case blockquote(AttributedString)
        case horizontalRule
    }
}

// MARK: - Markdown Parser

final class MarkdownParser {

    /// Parse markdown text into an array of typed blocks
    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            if trimmedLine.isEmpty {
                i += 1
                continue
            }

            // Code block detection (```)
            if trimmedLine.hasPrefix("```") {
                let (codeBlock, consumed) = parseCodeBlock(lines: lines, startIndex: i)
                if let codeBlock = codeBlock {
                    blocks.append(codeBlock)
                }
                i += consumed
                continue
            }

            // Table detection (| header | header |)
            if trimmedLine.hasPrefix("|") && trimmedLine.contains("|") {
                let (tableBlock, consumed) = parseTable(lines: lines, startIndex: i)
                if let tableBlock = tableBlock {
                    blocks.append(tableBlock)
                }
                i += consumed
                continue
            }

            // Horizontal rule (---, ***, ___)
            if isHorizontalRule(trimmedLine) {
                blocks.append(MarkdownBlock(type: .horizontalRule))
                i += 1
                continue
            }

            // Header detection (# ## ### etc.)
            if let header = parseHeader(trimmedLine) {
                blocks.append(header)
                i += 1
                continue
            }

            // Blockquote detection (> )
            if trimmedLine.hasPrefix("> ") || trimmedLine == ">" {
                let (quoteBlock, consumed) = parseBlockquote(lines: lines, startIndex: i)
                if let quoteBlock = quoteBlock {
                    blocks.append(quoteBlock)
                }
                i += consumed
                continue
            }

            // Bullet list detection (- or * or •)
            if isBulletListItem(trimmedLine) {
                let (listBlock, consumed) = parseBulletList(lines: lines, startIndex: i)
                if let listBlock = listBlock {
                    blocks.append(listBlock)
                }
                i += consumed
                continue
            }

            // Numbered list detection (1. 2. 3. etc.)
            if isNumberedListItem(trimmedLine) {
                let (listBlock, consumed) = parseNumberedList(lines: lines, startIndex: i)
                if let listBlock = listBlock {
                    blocks.append(listBlock)
                }
                i += consumed
                continue
            }

            // Default: paragraph with inline formatting
            let (paragraphBlock, consumed) = parseParagraph(lines: lines, startIndex: i)
            if let paragraphBlock = paragraphBlock {
                blocks.append(paragraphBlock)
            }
            i += consumed
        }

        return blocks
    }

    // MARK: - Inline Markdown Parsing

    /// Parse inline markdown (bold, italic, code, links, strikethrough)
    static func parseInlineMarkdown(_ text: String) -> AttributedString {
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            return try AttributedString(markdown: text, options: options)
        } catch {
            // Fallback to plain text if parsing fails
            return AttributedString(text)
        }
    }

    // MARK: - Code Block Parsing

    private static func parseCodeBlock(lines: [String], startIndex: Int) -> (MarkdownBlock?, Int) {
        guard startIndex < lines.count else { return (nil, 1) }

        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard firstLine.hasPrefix("```") else { return (nil, 1) }

        // Extract language from first line (e.g., ```swift)
        let language = firstLine.count > 3 ? String(firstLine.dropFirst(3)).trimmingCharacters(in: .whitespaces) : nil
        let languageStr = language?.isEmpty == true ? nil : language

        var codeLines: [String] = []
        var i = startIndex + 1

        // Collect lines until closing ```
        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                i += 1
                break
            }
            codeLines.append(line)
            i += 1
        }

        let code = codeLines.joined(separator: "\n")
        return (MarkdownBlock(type: .codeBlock(language: languageStr, code: code)), i - startIndex)
    }

    // MARK: - Table Parsing

    private static func parseTable(lines: [String], startIndex: Int) -> (MarkdownBlock?, Int) {
        guard startIndex < lines.count else { return (nil, 1) }

        var tableLines: [String] = []
        var i = startIndex

        // Collect all table lines (lines containing |)
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.contains("|") {
                tableLines.append(line)
                i += 1
            } else if line.isEmpty && !tableLines.isEmpty {
                // Allow empty line to end table
                break
            } else if !tableLines.isEmpty {
                break
            } else {
                i += 1
            }
        }

        guard tableLines.count >= 2 else { return (nil, i - startIndex) }

        // Parse headers (first row)
        let headers = parseTableRow(tableLines[0])

        // Skip separator row (second row with ---)
        var dataStartIndex = 1
        if tableLines.count > 1 && tableLines[1].contains("-") {
            dataStartIndex = 2
        }

        // Parse data rows
        var rows: [[String]] = []
        for rowIndex in dataStartIndex..<tableLines.count {
            let row = parseTableRow(tableLines[rowIndex])
            if !row.isEmpty {
                rows.append(row)
            }
        }

        guard !headers.isEmpty else { return (nil, i - startIndex) }

        return (MarkdownBlock(type: .table(headers: headers, rows: rows)), i - startIndex)
    }

    private static func parseTableRow(_ line: String) -> [String] {
        // Split by | and clean up
        let parts = line.split(separator: "|", omittingEmptySubsequences: false)
        var cells: [String] = []

        for part in parts {
            let cell = part.trimmingCharacters(in: .whitespaces)
            // Skip empty cells at the beginning/end from leading/trailing |
            if !cell.isEmpty && !cell.allSatisfy({ $0 == "-" || $0 == ":" }) {
                cells.append(cell)
            }
        }

        return cells
    }

    // MARK: - Header Parsing

    private static func parseHeader(_ line: String) -> MarkdownBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Count leading # characters
        var level = 0
        for char in trimmed {
            if char == "#" {
                level += 1
            } else {
                break
            }
        }

        guard level > 0 && level <= 6 else { return nil }

        // Get header text (after # and space)
        let headerText = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
        guard !headerText.isEmpty else { return nil }

        let attributedText = parseInlineMarkdown(headerText)
        return MarkdownBlock(type: .header(level: level, text: attributedText))
    }

    // MARK: - Blockquote Parsing

    private static func parseBlockquote(lines: [String], startIndex: Int) -> (MarkdownBlock?, Int) {
        var quoteLines: [String] = []
        var i = startIndex

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("> ") {
                quoteLines.append(String(line.dropFirst(2)))
                i += 1
            } else if line == ">" {
                quoteLines.append("")
                i += 1
            } else {
                break
            }
        }

        guard !quoteLines.isEmpty else { return (nil, 1) }

        let quoteText = quoteLines.joined(separator: "\n")
        let attributedText = parseInlineMarkdown(quoteText)
        return (MarkdownBlock(type: .blockquote(attributedText)), i - startIndex)
    }

    // MARK: - List Parsing

    private static func isBulletListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ")
    }

    private static func isNumberedListItem(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Match patterns like "1. ", "2. ", "10. "
        let pattern = #"^\d+\.\s"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    private static func parseBulletList(lines: [String], startIndex: Int) -> (MarkdownBlock?, Int) {
        var items: [AttributedString] = []
        var i = startIndex

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if isBulletListItem(trimmed) {
                // Extract item text (remove bullet prefix)
                var itemText = trimmed
                if trimmed.hasPrefix("- ") {
                    itemText = String(trimmed.dropFirst(2))
                } else if trimmed.hasPrefix("* ") {
                    itemText = String(trimmed.dropFirst(2))
                } else if trimmed.hasPrefix("• ") {
                    itemText = String(trimmed.dropFirst(2))
                }
                items.append(parseInlineMarkdown(itemText))
                i += 1
            } else if trimmed.isEmpty {
                // Empty line ends the list
                break
            } else {
                break
            }
        }

        guard !items.isEmpty else { return (nil, 1) }
        return (MarkdownBlock(type: .bulletList(items: items)), i - startIndex)
    }

    private static func parseNumberedList(lines: [String], startIndex: Int) -> (MarkdownBlock?, Int) {
        var items: [AttributedString] = []
        var i = startIndex

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if isNumberedListItem(trimmed) {
                // Extract item text (remove number prefix like "1. ")
                if let dotIndex = trimmed.firstIndex(of: ".") {
                    let afterDot = trimmed.index(after: dotIndex)
                    if afterDot < trimmed.endIndex {
                        let itemText = String(trimmed[afterDot...]).trimmingCharacters(in: .whitespaces)
                        items.append(parseInlineMarkdown(itemText))
                    }
                }
                i += 1
            } else if trimmed.isEmpty {
                break
            } else {
                break
            }
        }

        guard !items.isEmpty else { return (nil, 1) }
        return (MarkdownBlock(type: .numberedList(items: items)), i - startIndex)
    }

    // MARK: - Paragraph Parsing

    private static func parseParagraph(lines: [String], startIndex: Int) -> (MarkdownBlock?, Int) {
        var paragraphLines: [String] = []
        var i = startIndex

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Stop at empty line or special block markers
            if trimmed.isEmpty {
                break
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("#") || trimmed.hasPrefix("> ") ||
               trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") ||
               isNumberedListItem(trimmed) || (trimmed.hasPrefix("|") && trimmed.contains("|")) ||
               isHorizontalRule(trimmed) {
                break
            }

            paragraphLines.append(line)
            i += 1
        }

        guard !paragraphLines.isEmpty else { return (nil, max(1, i - startIndex)) }

        let paragraphText = paragraphLines.joined(separator: " ")
        let attributedText = parseInlineMarkdown(paragraphText)
        return (MarkdownBlock(type: .paragraph(attributedText)), i - startIndex)
    }

    // MARK: - Horizontal Rule Detection

    private static func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Match ---, ***, or ___ (at least 3 characters, optionally with spaces)
        let cleaned = trimmed.replacingOccurrences(of: " ", with: "")
        return (cleaned.count >= 3) &&
               (cleaned.allSatisfy { $0 == "-" } ||
                cleaned.allSatisfy { $0 == "*" } ||
                cleaned.allSatisfy { $0 == "_" })
    }
}
