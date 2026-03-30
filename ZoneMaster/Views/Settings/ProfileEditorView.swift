import SwiftUI

/// Profile management UI — create, rename, duplicate, delete, and switch profiles.
struct ProfileEditorView: View {
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var zoneEngine: ZoneEngine

    @State private var newProfileName: String = ""
    @State private var selectedPresetForNew: ZonePreset = .threeEqualColumns
    @State private var showingNewProfileSheet = false
    @State private var renamingProfileId: UUID?
    @State private var renameText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // Profile list
            List {
                ForEach(profileStore.appState.profiles) { profile in
                    HStack {
                        // Active indicator
                        Image(systemName: profile.id == profileStore.appState.activeProfileId ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(profile.id == profileStore.appState.activeProfileId ? .accentColor : .secondary)
                            .onTapGesture {
                                profileStore.setActiveProfile(profile)
                                if zoneEngine.isActive {
                                    zoneEngine.updateZones(profile.zones)
                                }
                            }

                        // Name (editable)
                        if renamingProfileId == profile.id {
                            TextField("Profile name", text: $renameText, onCommit: {
                                profileStore.renameProfile(profile, to: renameText)
                                renamingProfileId = nil
                            })
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                        } else {
                            Text(profile.name)
                                .font(.body)
                                .onTapGesture(count: 2) {
                                    renamingProfileId = profile.id
                                    renameText = profile.name
                                }
                        }

                        if profile.isDefault {
                            Text("Default")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(4)
                        }

                        Spacer()

                        // Zone count
                        Text("\(profile.zones.count) zones")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Layout source
                        if case .preset(let preset) = profile.layoutSource {
                            Text(preset.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Custom")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Actions
                        Button(action: {
                            let dup = profileStore.duplicateProfile(profile)
                            profileStore.setActiveProfile(dup)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Duplicate")

                        Button(action: {
                            renamingProfileId = profile.id
                            renameText = profile.name
                        }) {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Rename")

                        if profileStore.appState.profiles.count > 1 {
                            Button(action: {
                                profileStore.deleteProfile(profile)
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                            .help("Delete")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)

            // New profile button
            HStack {
                Spacer()
                Button(action: { showingNewProfileSheet = true }) {
                    Label("New Profile", systemImage: "plus")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showingNewProfileSheet) {
            newProfileSheet
        }
    }

    private var newProfileSheet: some View {
        VStack(spacing: 16) {
            Text("New Profile")
                .font(.headline)

            TextField("Profile name", text: $newProfileName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            Picker("Starting layout:", selection: $selectedPresetForNew) {
                ForEach(ZonePreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .frame(width: 250)

            HStack {
                Button("Cancel") {
                    showingNewProfileSheet = false
                    newProfileName = ""
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    guard !newProfileName.isEmpty else { return }
                    let profile = profileStore.createProfile(name: newProfileName, from: selectedPresetForNew)
                    profileStore.setActiveProfile(profile)
                    showingNewProfileSheet = false
                    newProfileName = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newProfileName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 350)
    }
}
