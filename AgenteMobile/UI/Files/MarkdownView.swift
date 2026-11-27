//
//  MarkdownView.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import SwiftUI

// MARK: - Block Model

private enum MarkdownBlock {
    case heading(level: Int, text: String)
    case codeBlock(language: String?, code: String)
    case bulletItem(depth: Int, text: String)
    case numberedItem(number: Int, text: String)
    case blockquote(text: String)
    case rule
    case blank
    case paragraph(text: String)
}

// MARK: - MarkdownView

struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks.indices, id: \.self) { index in
                blockView(for: blocks[index])
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Block Renderers

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inlineText(text)
                .font(headingFont(level))
                .padding(.top, level == 1 ? 16 : 10)
                .padding(.bottom, 2)

        case .codeBlock(_, let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.isEmpty ? " " : code)
                    .font(.system(.footnote, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.vertical, 6)

        case .bulletItem(let depth, let text):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .padding(.leading, CGFloat(depth) * 16 + 4)
                inlineText(text)
            }
            .padding(.vertical, 1)

        case .numberedItem(let number, let text):
            HStack(alignment: .top, spacing: 6) {
                Text("\(number).")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 24, alignment: .trailing)
                inlineText(text)
            }
            .padding(.vertical, 1)

        case .blockquote(let text):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: 3)
                    .padding(.vertical, 2)
                inlineText(text)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

        case .rule:
            Divider()
                .padding(.vertical, 8)

        case .blank:
            Spacer()
                .frame(height: 10)

        case .paragraph(let text):
            inlineText(text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 2)
        }
    }

    // MARK: - Inline Text (handles **bold**, *italic*, `code`, [links](url))

    @ViewBuilder
    private func inlineText(_ markdown: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
        } else {
            Text(markdown)
        }
    }

    // MARK: - Helpers

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title.bold()
        case 2: return .title2.bold()
        case 3: return .title3.bold()
        default: return .headline
        }
    }

    // MARK: - Parser

    private var blocks: [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        let lines = text.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let raw  = lines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            // ── Fenced code block ────────────────────────────────────────────
            if trimmed.hasPrefix("```") {
                let lang = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count &&
                      !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                result.append(.codeBlock(
                    language: lang.isEmpty ? nil : lang,
                    code: codeLines.joined(separator: "\n")
                ))
                i += 1 // skip closing ```
                continue
            }

            // ── Heading ──────────────────────────────────────────────────────
            if trimmed.hasPrefix("#") {
                let level = min(trimmed.prefix(while: { $0 == "#" }).count, 6)
                let text  = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                result.append(.heading(level: level, text: text))
                i += 1
                continue
            }

            // ── Horizontal rule ──────────────────────────────────────────────
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append(.rule)
                i += 1
                continue
            }

            // ── Bullet list ──────────────────────────────────────────────────
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                let depth = raw.prefix(while: { $0 == " " }).count / 2
                let text  = String(trimmed.dropFirst(2))
                result.append(.bulletItem(depth: depth, text: text))
                i += 1
                continue
            }

            // ── Numbered list ────────────────────────────────────────────────
            if let (number, text) = parseNumberedItem(trimmed) {
                result.append(.numberedItem(number: number, text: text))
                i += 1
                continue
            }

            // ── Blockquote ───────────────────────────────────────────────────
            if trimmed.hasPrefix("> ") {
                result.append(.blockquote(text: String(trimmed.dropFirst(2))))
                i += 1
                continue
            }

            // ── Blank line ───────────────────────────────────────────────────
            if trimmed.isEmpty {
                // Collapse multiple blank lines into one
                if result.last.map({ if case .blank = $0 { true } else { false } }) != true {
                    result.append(.blank)
                }
                i += 1
                continue
            }

            // ── Paragraph (collect until a block-level element or blank) ─────
            var paragraphLines: [String] = [trimmed]
            i += 1
            while i < lines.count {
                let next = lines[i].trimmingCharacters(in: .whitespaces)
                if next.isEmpty
                    || next.hasPrefix("#")
                    || next.hasPrefix("```")
                    || next.hasPrefix("- ")
                    || next.hasPrefix("* ")
                    || next.hasPrefix("+ ")
                    || next.hasPrefix("> ")
                    || next == "---" || next == "***" || next == "___"
                    || parseNumberedItem(next) != nil {
                    break
                }
                paragraphLines.append(next)
                i += 1
            }
            result.append(.paragraph(text: paragraphLines.joined(separator: " ")))
        }

        return result
    }

    /// Parses `"1. Some text"` → `(1, "Some text")`, or returns nil.
    private func parseNumberedItem(_ line: String) -> (Int, String)? {
        var rest = line[line.startIndex...]
        var digits = ""
        while let c = rest.first, c.isNumber {
            digits.append(c)
            rest = rest.dropFirst()
        }
        guard !digits.isEmpty,
              rest.hasPrefix(". "),
              let number = Int(digits) else { return nil }
        return (number, String(rest.dropFirst(2)))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        MarkdownView(text: """
        # Hello World

        This is a **bold** statement with *italic* and `inline code`.

        ## Lists

        - First item
        - Second item
          - Nested item
        - Third item

        1. Step one
        2. Step two
        3. Step three

        ## Code Block

        ```swift
        func greet() {
            print("Hello, World!")
        }
        ```

        > This is a blockquote with some important information.

        ---

        Regular paragraph with [a link](https://example.com) and more text.
        """)
        .padding()
    }
}
