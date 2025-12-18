import SwiftUI

/// View for displaying track identification results from Smart Tag
struct IdentifyView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.identifyResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Tracks to Identify")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("Scan your library first, then click Identify.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.identifyResults) { result in
                            IdentifyResultRow(result: result)
                        }
                    }
                }
            }
            .navigationTitle("Smart Tag")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.showIdentifyView = false
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        if viewModel.isIdentifying {
                            Button(role: .destructive) {
                                viewModel.abortIdentification()
                            } label: {
                                Label("Abort", systemImage: "xmark.circle.fill")
                            }
                            .buttonStyle(.bordered)
                            
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct IdentifyResultRow: View {
    let result: IdentifyResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Original track info
            HStack {
                VStack(alignment: .leading) {
                    Text("Original:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.originalTrack.title)
                        .font(.headline)
                    Text("\(result.originalTrack.artist) • \(result.originalTrack.album)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusBadge
            }
            
            // Suggested metadata (if found)
            if let metadata = result.selectedMetadata {
                Divider()
                
                HStack {
                    // Artwork
                    if let artworkURL = metadata.artworkURL {
                        AsyncImage(url: artworkURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 50, height: 50)
                        .cornerRadius(4)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Suggested:")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(metadata.title)
                            .font(.headline)
                            .foregroundColor(.green)
                        Text("\(metadata.artist) • \(metadata.album)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let year = metadata.year {
                            Text("Year: \(year)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(Int(metadata.confidence * 100))%")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch result.status {
        case .pending:
            Text("Pending")
                .font(.caption)
                .foregroundColor(.secondary)
        case .identifying:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Identifying...")
                    .font(.caption)
            }
        case .found(let count):
            Text("\(count) match\(count > 1 ? "es" : "")")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(8)
        case .notFound:
            Text("Not Found")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(8)
        case .error(let message):
            Text(message)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(8)
                .lineLimit(1)
        }
    }
}
