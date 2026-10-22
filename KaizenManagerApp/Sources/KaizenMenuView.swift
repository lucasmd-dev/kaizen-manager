import SwiftUI

struct KaizenMenuView: View {
    @ObservedObject var serviceRunner: ProjectRunner
    @ObservedObject var mobRunner: ProjectRunner
    @ObservedObject var toolsRunner: ProjectRunner
    @ObservedObject var controlRunner: ProjectRunner

    var quitAction: () -> Void
    var startAllAction: () -> Void
    var stopAllAction: () -> Void
    var changeFolderAction: (ProjectRunner) -> Void

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    MenuButton(title: "Start All", shortcut: "⌘S", action: startAllAction)
                    MenuButton(title: "Stop All", shortcut: "⌘X", action: stopAllAction)
                }

                Divider().padding(.horizontal, 10).padding(.vertical, 4)

                Group {
                    RunnerRow(runner: serviceRunner, changeFolderAction: { changeFolderAction(serviceRunner) })
                    RunnerRow(runner: mobRunner,    changeFolderAction: { changeFolderAction(mobRunner) })
                    RunnerRow(runner: toolsRunner,  changeFolderAction: { changeFolderAction(toolsRunner) })
                    RunnerRow(runner: controlRunner, changeFolderAction: { changeFolderAction(controlRunner) })
                }

                Divider().padding(.horizontal, 10).padding(.vertical, 4)

                MenuButton(title: "Quit", shortcut: "⌘Q", action: quitAction)
            }
            .padding(.vertical, 8)
            .frame(width: 250)
            .background(VisualEffectView())
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.material = .menu
        view.blendingMode = .behindWindow
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct RunnerRow: View {
    @ObservedObject var runner: ProjectRunner
    @State private var isFetching = false
    @State private var isPulling = false
    var changeFolderAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HoverButton(action: {
                if runner.status == .stopped || runner.status == .error {
                    runner.start()
                } else {
                    runner.stop()
                }
            }) {
                HStack(spacing: 6) {
                    iconForStatus(runner.status).frame(width: 16)
                    Text(runner.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                    Spacer()
                }
            }

            HStack(spacing: 4) {
                Spacer().frame(width: 22)

                Picker("", selection: Binding(
                    get: { runner.gitMonitor.currentBranch },
                    set: { runner.gitMonitor.checkout(branch: $0) }
                )) {
                    if !runner.gitMonitor.availableBranches.contains(runner.gitMonitor.currentBranch) {
                        Text(runner.gitMonitor.currentBranch).tag(runner.gitMonitor.currentBranch)
                    }
                    ForEach(runner.gitMonitor.availableBranches, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }
                .labelsHidden()
                .pickerStyle(MenuPickerStyle())
                .controlSize(.small)

                Spacer()

                // Change project folder
                Button(action: changeFolderAction) {
                    Image(systemName: "folder.badge.gear")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Alterar pasta do \(runner.name)")

                // git fetch
                Button(action: {
                    isFetching = true
                    runner.gitMonitor.fetchRemote { isFetching = false }
                }) {
                    Image(systemName: isFetching ? "arrow.triangle.2.circlepath" : "arrow.down.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("git fetch")

                // git pull
                Button(action: {
                    isPulling = true
                    runner.gitMonitor.pullCurrent { isPulling = false }
                }) {
                    Image(systemName: isPulling ? "arrow.triangle.2.circlepath" : "arrow.down.to.line")
                        .font(.system(size: 11))
                        .foregroundColor(isPulling ? .yellow : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("git pull")

                // Abrir log
                Button(action: { runner.openLog() }) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .foregroundColor(runner.status == .error ? .red : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help(runner.lastError.isEmpty ? "Abrir log" : runner.lastError)
            }
            .padding(.bottom, 2)
        }
        .padding(.trailing, 10)
    }

    @ViewBuilder
    func iconForStatus(_ status: ProjectStatus) -> some View {
        switch status {
        case .stopped:
            Image(systemName: "play.circle.fill").foregroundColor(.blue)
        case .starting:
            Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.yellow)
        case .running:
            Image(systemName: "stop.circle.fill").foregroundColor(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
        }
    }
}

struct MenuButton: View {
    var title: String
    var shortcut: String? = nil
    var action: () -> Void

    var body: some View {
        HoverButton(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .padding(.leading, 24)
                Spacer()
                if let shortcut = shortcut {
                    Text(shortcut).font(.system(size: 13)).opacity(0.6)
                }
            }
        }
    }
}

struct HoverButton<Content: View>: View {
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.accentColor : Color.clear)
        .foregroundColor(isHovered ? .white : .primary)
        .cornerRadius(4)
        .padding(.horizontal, 6)
        .onHover { hovering in isHovered = hovering }
    }
}
