import SwiftUI

struct TrackRowView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @ObservedObject var audioPlayer: AudioPlayerService
    
    let track: TrackModel
    let isSelected: Bool
    let isKept: Bool
    var onToggle: () -> Void
    
    private var isPlaying: Bool {
        audioPlayer.currentTrackId == track.id && audioPlayer.isPlaying
    }
    
    var body: some View {
        HStack {
            // Checkbox for selection state
            Image(systemName: isSelected ? "checkmark.circle.fill" : (isKept ? "lock.fill" : "circle"))
                .foregroundColor(isSelected ? .red : (isKept ? .green : .secondary))
                .onTapGesture {
                    onToggle()
                }
            
            // Play indicator - shows on currently playing track
            Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                .foregroundColor(isPlaying ? .accentColor : .clear)
                .font(.caption)
                .frame(width: 16)
            
            VStack(alignment: .leading) {
                Text(track.title)
                    .font(.headline)
                    .strikethrough(isSelected)
                Text("\(track.artist) • \(track.album)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(formatDuration(track.duration))
                    .monospacedDigit()
                Text(track.fileFormat.uppercased())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(isSelected ? 0.6 : 1.0)
        .background(isPlaying ? Color.accentColor.opacity(0.1) : (isSelected ? Color.red.opacity(0.05) : Color.clear))
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            // Play this track on tap
            viewModel.playTrackIfEnabled(track)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
