//
//  Citation.swift
//  pods
//
//  Created by Dimi Nunez on 12/17/25.
//


//
//  MarkdownMessageView.swift
//  pods
//
//  Created by Claude on 12/17/25.
//

import SwiftUI

// MARK: - Citation Model

struct Citation: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let url: String?
    let domain: String?
    let snippet: String?

    var displayDomain: String {
        domain ?? (url.flatMap { URL(string: $0)?.host } ?? "Source")
    }
}

// MARK: - Markdown Message View

/// A view that renders markdown-formatted text with support for:
/// - Headers, bold, italic, strikethrough
/// - Code blocks with copy button
/// - Tables with horizontal scroll
/// - Bullet and numbered lists
/// - Blockquotes
/// - Links (tappable)
/// - Citations footer
struct MarkdownMessageView: View {
    let text: String
    var citations: [Citation]?
    var onLinkTapped: ((URL) -> Void)?
    var onCitationTapped: ((Citation) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(MarkdownParser.parse(text)) { block in
                MarkdownBlockView(
                    block: block,
                    onLinkTapped: onLinkTapped
                )
            }

            // Citations footer
            if let citations = citations, !citations.isEmpty {
                CitationsFooterView(
                    citations: citations,
                    onTap: onCitationTapped
                )
            }
        }
    }
}

// MARK: - Block View

/// Renders individual markdown blocks based on their type
struct MarkdownBlockView: View {
    let block: MarkdownBlock
    var onLinkTapped: ((URL) -> Void)?

    var body: some View {
        switch block.type {
        case .paragraph(let text):
            Text(text)
                .textSelection(.enabled)
                .environment(\.openURL, OpenURLAction { url in
                    onLinkTapped?(url)
                    return .handled
                })

        case .header(let level, let text):
            headerView(level: level, text: text)

        case .codeBlock(let language, let code):
            CodeBlockView(language: language, code: code)

        case .table(let headers, let rows):
            MarkdownTableView(headers: headers, rows: rows)

        case .bulletList(let items):
            bulletListView(items: items)

        case .numberedList(let items):
            numberedListView(items: items)

        case .blockquote(let text):
            blockquoteView(text: text)

        case .horizontalRule:
            horizontalRuleView
        }
    }

    // MARK: - Header View

    @ViewBuilder
    private func headerView(level: Int, text: AttributedString) -> some View {
        Text(text)
            .font(headerFont(for: level))
            .fontWeight(.semibold)
            .textSelection(.enabled)
            .padding(.top, level <= 2 ? 8 : 4)
    }

    private func headerFont(for level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        case 4: return .headline
        default: return .subheadline
        }
    }

    // MARK: - Bullet List View

    @ViewBuilder
    private func bulletListView(items: [AttributedString]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(item)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Numbered List View

    @ViewBuilder
    private func numberedListView(items: [AttributedString]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .foregroundColor(.secondary)
                        .frame(minWidth: 20, alignment: .trailing)
                    Text(item)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Blockquote View

    @ViewBuilder
    private func blockquoteView(text: AttributedString) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 3)

            Text(text)
                .foregroundColor(.secondary)
                .padding(.leading, 12)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Horizontal Rule View

    private var horizontalRuleView: some View {
        Divider()
            .padding(.vertical, 8)
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let language: String?
    let code: String

    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language label and copy button
            HStack {
                if let lang = language, !lang.isEmpty {
                    Text(lang)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        if isCopied {
                            Text("Copied")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(isCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private func copyCode() {
        UIPasteboard.general.string = code
        withAnimation {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

// MARK: - Markdown Table View

struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(headers.indices, id: \.self) { i in
                        Text(headers[i])
                            .font(.subheadline.bold())
                            .padding(10)
                            .frame(minWidth: 80, alignment: .leading)
                            .background(Color(.tertiarySystemBackground))

                        if i < headers.count - 1 {
                            Divider()
                        }
                    }
                }

                Divider()

                // Data rows
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        ForEach(rows[rowIndex].indices, id: \.self) { colIndex in
                            Text(colIndex < rows[rowIndex].count ? rows[rowIndex][colIndex] : "")
                                .font(.subheadline)
                                .padding(10)
                                .frame(minWidth: 80, alignment: .leading)

                            if colIndex < headers.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .background(rowIndex % 2 == 0 ? Color.clear : Color(.secondarySystemBackground).opacity(0.5))

                    if rowIndex < rows.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .cornerRadius(8)
    }
}

// MARK: - Citations Footer View

struct CitationsFooterView: View {
    let citations: [Citation]
    var onTap: ((Citation) -> Void)?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsed header
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }}) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                    Text("\(citations.count) source\(citations.count == 1 ? "" : "s")")
                        .font(.caption)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            // Expanded source list
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(citations) { citation in
                        CitationRowView(citation: citation, onTap: onTap)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 12)
    }
}

// MARK: - Citation Row View

struct CitationRowView: View {
    let citation: Citation
    var onTap: ((Citation) -> Void)?

    var body: some View {
        Button(action: { onTap?(citation) }) {
            HStack(spacing: 10) {
                // Citation number badge
                Text(citation.id)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.accentColor)
                    .clipShape(Circle())

                // Citation info
                VStack(alignment: .leading, spacing: 2) {
                    Text(citation.title)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(citation.displayDomain)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // External link icon
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Markdown Message") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            MarkdownMessageView(
                text: """
                # Welcome to Markdown

                This is a **bold** and *italic* test with `inline code`.

                ## Features

                - First bullet point
                - Second bullet point
                - Third with **bold** text

                1. First numbered item
                2. Second numbered item

                > This is a blockquote with some wisdom.

                ```swift
                func hello() {
                    print("Hello, World!")
                }
                ```

                | Food | Calories | Protein |
                |------|----------|---------|
                | Chicken | 165 | 31g |
                | Rice | 130 | 2.7g |

                ---

                That's all folks!
                """,
                citations: [
                    Citation(id: "1", title: "USDA FoodData Central", url: "https://fdc.nal.usda.gov", domain: "fdc.nal.usda.gov", snippet: "Nutrient data source"),
                    Citation(id: "2", title: "Mayo Clinic - Nutrition", url: "https://mayoclinic.org", domain: "mayoclinic.org", snippet: "Health information")
                ]
            )
            .padding()
        }
    }
}
