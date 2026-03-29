//
//  AboutLocTracView.swift
//  LocTrac
//
//  Created by Tim Arey on 12/19/25.
//

import SwiftUI

struct AboutLocTracView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
    // Read from custom Info.plist key "AppReleaseDate"
    private var releaseDate: String {
        Bundle.main.infoDictionary?["AppReleaseDate"] as? String ?? "—"
    }
    private let author: String = "Tim Arey"
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("App")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text("LocTrac")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Release Date")
                        Spacer()
                        Text(releaseDate)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section(header: Text("Author")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(author)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("About LocTrac")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
