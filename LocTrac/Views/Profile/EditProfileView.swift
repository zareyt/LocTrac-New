// EditProfileView.swift
// LocTrac
// Edit display name, email, and profile photo
// v2.0

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authState: AuthState

    @State private var displayName = ""
    @State private var email = ""
    @State private var photoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingRemovePhotoConfirm = false

    private var hasPhoto: Bool {
        photoData != nil
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Profile photo
                    VStack(spacing: 12) {
                        if let photoData, let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.accentColor.opacity(0.3), lineWidth: 2))
                        } else {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 120, height: 120)
                                .overlay {
                                    Text(initials)
                                        .font(.system(size: 42, weight: .bold))
                                        .foregroundStyle(Color.accentColor)
                                }
                        }

                        HStack(spacing: 16) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Text(hasPhoto ? "Change Photo" : "Add Photo")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                            }

                            if hasPhoto {
                                Button {
                                    showingRemovePhotoConfirm = true
                                } label: {
                                    Text("Remove")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                            }
                        }
                    }
                    .padding(.top, 12)

                    // Fields
                    VStack(spacing: 20) {
                        editField(label: "DISPLAY NAME", text: $displayName, placeholder: "Your name", contentType: .name)
                        editField(label: "EMAIL", text: $email, placeholder: "your@email.com", contentType: .emailAddress, keyboardType: .emailAddress)
                    }
                    .padding(.horizontal, 32)

                    Spacer(minLength: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color.accentColor)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveProfile()
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.accentColor)
            }
        }
        .onAppear {
            if let profile = authState.currentUser {
                displayName = profile.displayName
                email = profile.email ?? ""
                photoData = profile.photoData
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    if let uiImage = UIImage(data: data),
                       let resized = uiImage.jpegData(compressionQuality: 0.7) {
                        photoData = resized
                    }
                }
            }
        }
        .alert("Remove Photo", isPresented: $showingRemovePhotoConfirm) {
            Button("Remove", role: .destructive) {
                photoData = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove your profile photo?")
        }
        .debugViewName("EditProfileView")
    }

    private func editField(label: String, text: Binding<String>, placeholder: String, contentType: UITextContentType? = nil, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .tracking(1.2)

            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboardType == .emailAddress)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
        }
    }

    private func saveProfile() {
        guard var profile = authState.currentUser else { return }
        profile.displayName = displayName
        profile.email = email.isEmpty ? nil : email
        profile.photoData = photoData
        authState.updateProfile(profile)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
    }
    .environmentObject(AuthState())
}
