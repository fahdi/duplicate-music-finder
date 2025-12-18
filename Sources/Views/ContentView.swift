import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView(audioPlayer: viewModel.audioPlayer)
        } detail: {
            Group {
                if viewModel.duplicateGroups.isEmpty {
                    VStack(spacing: 16) {
                        if viewModel.isScanning {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text(viewModel.statusMessage)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            Text("No duplicates found")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Text(viewModel.statusMessage)
                                .font(.caption)
                        }
                    }
                } else {
                    List {
                        ForEach(viewModel.duplicateGroups) { group in
                            DuplicateGroupView(group: group)
                        }
                    }
                }
            }
            .navigationTitle("Duplicate Music Finder")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Text("\(viewModel.duplicateGroups.count) Groups")
                }
            }
        }
        .alert("Remove Selected Duplicates?", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                viewModel.deleteSelectedTracks()
            }
        } message: {
            Text("This will move selected tracks to the Trash. You can undo this in Finder.")
        }
    }
}
