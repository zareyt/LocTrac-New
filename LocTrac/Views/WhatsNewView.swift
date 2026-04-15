//
//  WhatsNewView.swift
//  LocTrac
//
//  Paged "What's New" sheet shown once per version on first launch.
//  Each major feature gets its own page. The user taps "Next" to advance
//  and "Done" on the last page. Dismissing marks the version as seen.
//

import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    let features: [WhatsNewFeature]
    let bugFixes: [WhatsNewFeature]
    
    @State private var currentIndex: Int = 0

    // Convenience initialiser — looks up features for the running version
    init() {
        let content = WhatsNewFeature.content(for: AppVersionManager.currentVersion)
        self.features = content.features
        self.bugFixes = content.bugFixes
    }

    // Designated initialiser (useful for previews / testing)
    init(features: [WhatsNewFeature], bugFixes: [WhatsNewFeature] = []) {
        self.features = features
        self.bugFixes = bugFixes
    }
    
    private var totalPages: Int {
        features.count + (bugFixes.isEmpty ? 0 : 1)
    }

    private var isLastPage: Bool {
        currentIndex == totalPages - 1
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────────
                headerView

                // ── Feature pages + Bug fixes page ───────────────────────
                TabView(selection: $currentIndex) {
                    // Feature pages
                    ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                        FeaturePageView(feature: feature)
                            .tag(index)
                    }
                    
                    // Consolidated bug fixes page (if any)
                    if !bugFixes.isEmpty {
                        BugFixesPageView(bugFixes: bugFixes)
                            .tag(features.count)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(.easeInOut, value: currentIndex)

                // ── Navigation buttons ───────────────────────────────────
                navigationButtons
                    .padding(.horizontal)
                    .padding(.bottom, 32)
            }
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.08), .purple.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        markSeenAndDismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .interactiveDismissDisabled(false)
        .onDisappear {
            // Safety net: mark seen whenever the sheet disappears
            AppVersionManager.markCurrentVersionSeen()
        }
    }

    // MARK: - Sub-views

    private var headerView: some View {
        VStack(spacing: 6) {
            Text("What's New in LocTrac")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 28)

            Text("Version \(AppVersionManager.currentVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    private var navigationButtons: some View {
        HStack {
            // Back button — hidden on first page
            if currentIndex > 0 {
                Button {
                    withAnimation { currentIndex -= 1 }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
            } else {
                Spacer().frame(width: 80)
            }

            Spacer()

            if isLastPage {
                Button {
                    markSeenAndDismiss()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    withAnimation { currentIndex += 1 }
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private func markSeenAndDismiss() {
        AppVersionManager.markCurrentVersionSeen()
        dismiss()
    }
}

// MARK: - Individual Feature Page

private struct FeaturePageView: View {
    let feature: WhatsNewFeature

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(feature.symbolColor.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: feature.symbolName)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(feature.symbolColor)
            }

            // Text
            VStack(spacing: 12) {
                Text(feature.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(feature.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Bug Fixes Page

private struct BugFixesPageView: View {
    let bugFixes: [WhatsNewFeature]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    
                    Text("Bugs Fixed in v\(AppVersionManager.currentVersion)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("\(bugFixes.count) issue\(bugFixes.count == 1 ? "" : "s") resolved")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                // Bug fixes list
                VStack(spacing: 16) {
                    ForEach(bugFixes) { bug in
                        BugFixRowView(bug: bug)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 20)
            }
        }
    }
}

private struct BugFixRowView: View {
    let bug: WhatsNewFeature
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: bug.symbolName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(bug.symbolColor)
                .frame(width: 32, height: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(bug.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(bug.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Preview

#Preview("What's New — 1.5") {
    let content = WhatsNewFeature.content(for: "1.5")
    return WhatsNewView(features: content.features, bugFixes: content.bugFixes)
}

#Preview("Features Only") {
    WhatsNewView(features: [
        WhatsNewFeature(
            symbolName: "star.fill",
            symbolColor: .yellow,
            title: "Sample Feature",
            description: "This is a sample description for a great new feature."
        )
    ])
}

#Preview("With Bug Fixes") {
    WhatsNewView(
        features: [
            WhatsNewFeature(
                symbolName: "star.fill",
                symbolColor: .yellow,
                title: "New Feature",
                description: "A great new feature."
            )
        ],
        bugFixes: [
            WhatsNewFeature(
                symbolName: "checkmark.circle.fill",
                symbolColor: .green,
                title: "Fixed Bug",
                description: "This bug is now fixed."
            ),
            WhatsNewFeature(
                symbolName: "paintbrush.fill",
                symbolColor: .pink,
                title: "UI Fix",
                description: "Visual issue resolved."
            )
        ]
    )
}
