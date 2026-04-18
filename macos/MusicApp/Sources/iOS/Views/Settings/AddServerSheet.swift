import SwiftUI

struct AddServerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var serverType: String = "smb"
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var shareName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var testing = false
    @State private var testResult: Bool?

    private var parsedPort: Int? {
        guard !port.isEmpty else { return nil }
        guard let p = Int(port), (1...65535).contains(p) else { return nil }
        return p
    }

    private var portInvalid: Bool {
        !port.isEmpty && parsedPort == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Type picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Lang.sourceType)
                            .font(.caption)
                            .foregroundStyle(.gray)

                        VStack(spacing: 0) {
                            sourceTypeRow("smb", icon: "externaldrive.connected.to.line.below", label: Lang.smb, detail: Lang.smbDescription)
                            Divider().background(Color.white.opacity(0.05))
                            sourceTypeRow("subsonic", icon: "music.note.house", label: Lang.subsonic, detail: Lang.subsonicDescription)
                            Divider().background(Color.white.opacity(0.05))
                            sourceTypeRow("jellyfin", icon: "play.rectangle", label: Lang.jellyfin, detail: Lang.jellyfinDescription)
                        }
                        .glassCard()
                    }

                    // Fields
                    VStack(spacing: 0) {
                        fieldRow(Lang.serverName, text: $name, placeholder: Lang.current == "fr" ? "Mon NAS" : "My NAS")
                        Divider().background(Color.white.opacity(0.05))
                        fieldRow(Lang.address, text: $host, placeholder: serverType == "subsonic" || serverType == "jellyfin" ? "https://server.com" : "192.168.1.100")
                        if serverType == "smb" {
                            Divider().background(Color.white.opacity(0.05))
                            HStack {
                                fieldRow(Lang.port, text: $port, placeholder: "445")
                                if portInvalid {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                        .padding(.trailing, 12)
                                }
                            }
                            Divider().background(Color.white.opacity(0.05))
                            fieldRow(Lang.shareName, text: $shareName, placeholder: Lang.current == "fr" ? "Musique" : "Music")
                        }
                        Divider().background(Color.white.opacity(0.05))
                        fieldRow(Lang.username, text: $username, placeholder: "")
                        Divider().background(Color.white.opacity(0.05))
                        fieldRow(Lang.password, text: $password, placeholder: "", isSecure: true)
                    }
                    .glassCard()

                    // Test + Save
                    HStack(spacing: 12) {
                        Button {
                            testConnection()
                        } label: {
                            HStack {
                                if testing {
                                    ProgressView().controlSize(.small).tint(.white)
                                } else if let result = testResult {
                                    Image(systemName: result ? "checkmark.circle" : "xmark.circle")
                                        .foregroundStyle(result ? .green : .red)
                                }
                                Text(Lang.testConnection)
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            saveServer()
                        } label: {
                            Text(Lang.create)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(name.isEmpty || host.isEmpty || portInvalid)
                    }
                }
                .padding(16)
            }
            .background(Color.black)
            .navigationTitle(Lang.addSource)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func sourceTypeRow(_ type: String, icon: String, label: String, detail: String) -> some View {
        Button {
            serverType = type
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(serverType == type ? .white : .gray)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.gray.opacity(0.6))
                }
                Spacer()
                if serverType == type {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func fieldRow(_ label: String, text: Binding<String>, placeholder: String, isSecure: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .frame(width: 90, alignment: .leading)
            if isSecure {
                SecureField(placeholder, text: text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func testConnection() {
        testing = true
        testResult = nil
        Task {
            do {
                switch serverType {
                case "smb":
                    let config = ServerConfig(type: "smb", name: name, host: host, port: parsedPort ?? 445, shareName: shareName, username: username)
                    let client = SMBClient(config: config, password: password)
                    _ = try await client.testConnection()
                case "subsonic":
                    let config = ServerConfig(type: "subsonic", name: name, host: host, username: username)
                    let client = SubsonicClient(config: config, password: password)
                    _ = try await client.ping()
                case "jellyfin":
                    let config = ServerConfig(type: "jellyfin", name: name, host: host, username: username)
                    let client = JellyfinClient(config: config, password: password)
                    _ = try await client.ping()
                default: break
                }
                testResult = true
            } catch {
                testResult = false
            }
            testing = false
        }
    }

    private func saveServer() {
        let config = ServerConfig(type: serverType, name: name, host: host,
                                  port: serverType == "smb" ? (parsedPort ?? 445) : nil,
                                  shareName: serverType == "smb" ? shareName : nil,
                                  username: username)
        appState.db.insertServerConfig(config)
        KeychainHelper.save(key: "flayer-server-\(config.id)", value: password)
        dismiss()
    }
}
