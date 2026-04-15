//
//  MarkdownDocumentView.swift
//  LocTrac
//
//  A reusable sheet that loads a named Markdown file from the main bundle
//  and displays it as beautifully formatted HTML with full markdown support.
//
//  Usage:
//      .sheet(isPresented: $showReadme) {
//          MarkdownDocumentView(fileName: "README", title: "Read Me")
//      }
//
//  The file must be added to the Xcode target as "README.md".
//

import SwiftUI
import WebKit

struct MarkdownDocumentView: View {
    let fileName: String    // Name without extension, e.g. "README"
    let title: String       // Navigation bar title

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var htmlContent: String?
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if let error = loadError {
                    ContentUnavailableView(
                        "Document Not Found",
                        systemImage: "doc.questionmark",
                        description: Text(error)
                    )
                } else if let html = htmlContent {
                    MarkdownWebView(htmlContent: html, colorScheme: colorScheme)
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadDocument()
            }
        }
    }

    // MARK: - Loading

    @MainActor
    private func loadDocument() async {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "md") else {
            loadError = "\(fileName).md was not found in the app bundle.\nMake sure the file is added to the Xcode target."
            return
        }
        
        do {
            let markdown = try String(contentsOf: url, encoding: .utf8)
            htmlContent = convertMarkdownToHTML(markdown)
        } catch {
            loadError = "Could not read \(fileName).md: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Markdown to HTML Conversion
    
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        // Convert markdown to HTML with GitHub-style formatting
        let htmlBody = markdown
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .convertMarkdownHeaders()
            .convertMarkdownBold()
            .convertMarkdownItalic()
            .convertMarkdownCode()
            .convertMarkdownLinks()
            .convertMarkdownLists()
            .convertMarkdownHorizontalRules()
            .convertMarkdownLineBreaks()
        
        let isDark = colorScheme == .dark
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Arial, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    color: \(isDark ? "#ffffff" : "#000000");
                    background-color: \(isDark ? "#000000" : "#ffffff");
                    padding: 20px;
                    -webkit-text-size-adjust: 100%;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    margin-top: 24px;
                    margin-bottom: 16px;
                    line-height: 1.25;
                }
                
                h1 {
                    font-size: 32px;
                    border-bottom: 1px solid \(isDark ? "#30363d" : "#d0d7de");
                    padding-bottom: 8px;
                }
                
                h2 {
                    font-size: 24px;
                    border-bottom: 1px solid \(isDark ? "#30363d" : "#d0d7de");
                    padding-bottom: 8px;
                }
                
                h3 {
                    font-size: 20px;
                }
                
                h4 {
                    font-size: 16px;
                }
                
                h5 {
                    font-size: 14px;
                }
                
                h6 {
                    font-size: 13px;
                    color: \(isDark ? "#8b949e" : "#57606a");
                }
                
                p {
                    margin-bottom: 16px;
                }
                
                strong {
                    font-weight: 600;
                }
                
                em {
                    font-style: italic;
                }
                
                code {
                    background-color: \(isDark ? "#2d333b" : "#f6f8fa");
                    padding: 3px 6px;
                    border-radius: 6px;
                    font-family: 'SF Mono', 'Monaco', 'Menlo', monospace;
                    font-size: 14px;
                }
                
                pre {
                    background-color: \(isDark ? "#2d333b" : "#f6f8fa");
                    padding: 16px;
                    border-radius: 6px;
                    overflow-x: auto;
                    margin-bottom: 16px;
                }
                
                pre code {
                    background-color: transparent;
                    padding: 0;
                }
                
                ul, ol {
                    margin-left: 20px;
                    margin-bottom: 16px;
                }
                
                li {
                    margin-bottom: 8px;
                }
                
                a {
                    color: \(isDark ? "#58a6ff" : "#0969da");
                    text-decoration: none;
                }
                
                a:active {
                    opacity: 0.7;
                }
                
                hr {
                    height: 1px;
                    border: none;
                    background-color: \(isDark ? "#30363d" : "#d0d7de");
                    margin: 24px 0;
                }
                
                blockquote {
                    border-left: 4px solid \(isDark ? "#3b434b" : "#d0d7de");
                    padding-left: 16px;
                    margin-bottom: 16px;
                    color: \(isDark ? "#8b949e" : "#57606a");
                }
                
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin-bottom: 16px;
                }
                
                th, td {
                    border: 1px solid \(isDark ? "#30363d" : "#d0d7de");
                    padding: 8px;
                    text-align: left;
                }
                
                th {
                    background-color: \(isDark ? "#161b22" : "#f6f8fa");
                    font-weight: 600;
                }
            </style>
        </head>
        <body>
            \(htmlBody)
        </body>
        </html>
        """
    }
}

// MARK: - WebView Wrapper

private struct MarkdownWebView: UIViewRepresentable {
    let htmlContent: String
    let colorScheme: ColorScheme
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.dataDetectorTypes = [.link, .phoneNumber]
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
}

// MARK: - String Extensions for Markdown Conversion

private extension String {
    func convertMarkdownHeaders() -> String {
        var result = self
        
        // H1 through H6
        for level in (1...6).reversed() {
            let hashes = String(repeating: "#", count: level)
            let pattern = "^\(hashes) (.+)$"
            result = result.replacingOccurrences(
                of: pattern,
                with: "<h\(level)>$1</h\(level)>",
                options: .regularExpression,
                range: nil
            )
        }
        
        return result
    }
    
    func convertMarkdownBold() -> String {
        replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
            .replacingOccurrences(of: "__(.+?)__", with: "<strong>$1</strong>", options: .regularExpression)
    }
    
    func convertMarkdownItalic() -> String {
        replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
            .replacingOccurrences(of: "_(.+?)_", with: "<em>$1</em>", options: .regularExpression)
    }
    
    func convertMarkdownCode() -> String {
        replacingOccurrences(of: "`(.+?)`", with: "<code>$1</code>", options: .regularExpression)
    }
    
    func convertMarkdownLinks() -> String {
        replacingOccurrences(of: "\\[(.+?)\\]\\((.+?)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)
    }
    
    func convertMarkdownLists() -> String {
        let lines = self.components(separatedBy: .newlines)
        var inList = false
        var listType = ""
        var processedLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Unordered list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if !inList {
                    processedLines.append("<ul>")
                    inList = true
                    listType = "ul"
                }
                let content = String(trimmed.dropFirst(2))
                processedLines.append("<li>\(content)</li>")
            }
            // Ordered list
            else if trimmed.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
                if !inList {
                    processedLines.append("<ol>")
                    inList = true
                    listType = "ol"
                } else if listType != "ol" {
                    processedLines.append("</\(listType)>")
                    processedLines.append("<ol>")
                    listType = "ol"
                }
                let content = trimmed.replacingOccurrences(of: "^\\d+\\. ", with: "", options: .regularExpression)
                processedLines.append("<li>\(content)</li>")
            }
            // End of list
            else {
                if inList {
                    processedLines.append("</\(listType)>")
                    inList = false
                }
                processedLines.append(line)
            }
        }
        
        if inList {
            processedLines.append("</\(listType)>")
        }
        
        return processedLines.joined(separator: "\n")
    }
    
    func convertMarkdownHorizontalRules() -> String {
        replacingOccurrences(of: "^---$", with: "<hr>", options: .regularExpression)
            .replacingOccurrences(of: "^\\*\\*\\*$", with: "<hr>", options: .regularExpression)
    }
    
    func convertMarkdownLineBreaks() -> String {
        // Convert double line breaks to paragraphs
        let paragraphs = components(separatedBy: "\n\n")
        return paragraphs.map { para in
            let trimmed = para.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "" }
            if trimmed.hasPrefix("<h") || trimmed.hasPrefix("<ul") || 
               trimmed.hasPrefix("<ol") || trimmed.hasPrefix("<hr") ||
               trimmed.hasPrefix("<pre") { return trimmed }
            return "<p>\(trimmed.replacingOccurrences(of: "\n", with: "<br>"))</p>"
        }.joined(separator: "\n")
    }
}

// MARK: - Preview

#Preview {
    MarkdownDocumentView(fileName: "README", title: "Read Me")
}
