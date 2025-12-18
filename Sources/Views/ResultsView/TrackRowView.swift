import SwiftUI

struct TrackRowView: View {
    let track: TrackModel
    let isSelected: Bool
    let isKept: Bool
    var onToggle: () -> Void
    
    var body: some View {
        HStack {
            // Checkbox for selection state
            Image(systemName: isSelected ? "checkmark.circle.fill" : (isKept ? "lock.fill" : "circle"))
                .foregroundColor(isSelected ? .red : (isKept ? .green : .secondary))
                .onTapGesture {
                    onToggle()
                }
            
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
        .background(isSelected ? Color.red.opacity(0.05) : Color.clear)
        .cornerRadius(4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
