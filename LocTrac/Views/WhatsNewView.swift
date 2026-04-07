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

    @State private var currentIndex: Int = 0

    // Convenience initialiser — looks up features for the running version
    init() {
        self.features = WhatsNewFeature.features(for: AppVersionManager.currentVersion)
    }

    // Designated initialiser (useful for previews / testing)
    init(features: [WhatsNewFeature]) {
        self.features = features
    }

    private var isLastPage: Bool {
        currentIndex == features.count - 1
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────────
                headerView

                // ── Feature pages ────────────────────────────────────────
                TabView(selection: $currentIndex) {
                    ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                        FeaturePageView(feature: feature)
                            .tag(index)
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

// MARK: - Preview

#Preview("What's New — 1.3") {
    WhatsNewView(features: WhatsNewFeature.features(for: "1.3"))
}

#Preview("Single Feature") {
    WhatsNewView(features: [
        WhatsNewFeature(
            symbolName: "star.fill",
            symbolColor: .yellow,
            title: "Sample Feature",
            description: "This is a sample description for a great new feature."
        )
    ])
}
