//
//  AboutLocTracView.swift
//  LocTrac
//
//  About screen with app info, version, and links to documentation
//

import SwiftUI

struct AboutLocTracView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showReadme = false
    @State private var showChangelog = false
    @State private var showLicense = false
    @State private var showWhatsNew = false
    
    // Get app version and build number
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    // Check if there are "What's New" features for this version
    private var hasWhatsNewFeatures: Bool {
        !WhatsNewFeature.features(for: appVersion).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            List {
                // App Info Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "map.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.blue.gradient)
                            
                            Text("LocTrac")
                                .font(.title.bold())
                            
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
                
                // Documentation Section
                Section("Documentation") {
                    // What's New button (only shown if features exist for this version)
                    // TODO: Remove the 'true ||' after confirming version detection works
                    if true || hasWhatsNewFeatures {
                        Button {
                            showWhatsNew = true
                        } label: {
                            Label("What's New in Version \(appVersion)", systemImage: "sparkles")
                        }
                    }
                    
                    Button {
                        showReadme = true
                    } label: {
                        HStack {
                            Label("Read Me", systemImage: "doc.text")
                            Spacer()
                            // Debug indicator
                            if Bundle.main.url(forResource: "README", withExtension: "md") == nil {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Button {
                        showChangelog = true
                    } label: {
                        HStack {
                            Label("Changelog", systemImage: "list.bullet.rectangle")
                            Spacer()
                            // Debug indicator
                            if Bundle.main.url(forResource: "CHANGELOG", withExtension: "md") == nil {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Button {
                        showLicense = true
                    } label: {
                        HStack {
                            Label("License", systemImage: "checkmark.seal")
                            Spacer()
                            // Debug indicator
                            if Bundle.main.url(forResource: "LICENSE", withExtension: "md") == nil {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                // About Section
                Section("About") {
                    LabeledContent("Developer", value: "Tim Arey")
                    LabeledContent("Privacy", value: "100% Local Storage")
                    LabeledContent("Platform", value: "iOS 16.0+")
                }
                
                // Copyright Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Made with ❤️ and SwiftUI")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            
                            Text("© 2026 Tim Arey")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("About LocTrac")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            // Markdown document sheets
            .sheet(isPresented: $showReadme) {
                MarkdownDocumentView(fileName: "README", title: "Read Me")
            }
            .sheet(isPresented: $showChangelog) {
                MarkdownDocumentView(fileName: "CHANGELOG", title: "Changelog")
            }
            .sheet(isPresented: $showLicense) {
                MarkdownDocumentView(fileName: "LICENSE", title: "License")
            }
            // What's New sheet
            .sheet(isPresented: $showWhatsNew) {
                WhatsNewView()
            }
        }
    }
}

#Preview {
    AboutLocTracView()
}
