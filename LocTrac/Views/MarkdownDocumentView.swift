//
//  MarkdownDocumentView.swift
//  LocTrac
//
//  A reusable sheet that loads a named Markdown file from the main bundle
//  and displays it as formatted attributed text.
//
//  Usage:
//      .sheet(isPresented: $showReadme) {
//          MarkdownDocumentView(fileName: "README", title: "Read Me")
//      }
//
//  The file must be added to the Xcode target as "README.md".
//

import SwiftUI

struct MarkdownDocumentView: View {
    let fileName: String    // Name without extension, e.g. "README"
    let title: String       // Navigation bar title

    @Environment(\.dismiss) private var dismiss
    @State private var content: AttributedString = AttributedString("")
    @State private var loadError: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let error = loadError {
                        ContentUnavailableView(
                            "Document Not Found",
                            systemImage: "doc.questionmark",
                            description: Text(error)
                        )
                        .padding(.top, 60)
                    } else {
                        Text(content)
                            .padding()
                            .textSelection(.enabled)
                    }
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
            let rawText = try String(contentsOf: url, encoding: .utf8)
            content = (try? AttributedString(
                markdown: rawText,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlinesOnlyPreservingWhitespace
                )
            )) ?? AttributedString(rawText)
        } catch {
            loadError = "Could not read \(fileName).md: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    MarkdownDocumentView(fileName: "README", title: "Read Me")
}
