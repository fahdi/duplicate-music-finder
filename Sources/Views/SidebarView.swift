import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @ObservedObject var audioPlayer: AudioPlayerService
    
    var body: some View {
        Form {
            Section("Detection Criteria") {
                Toggle("Match Title", isOn: $viewModel.criteria.matchTitle)
                Toggle("Match Artist", isOn: $viewModel.criteria.matchArtist)
                Toggle("Match Album", isOn: $viewModel.criteria.matchAlbum)
                Toggle("Match Duration", isOn: $viewModel.criteria.matchDuration)
                
                if viewModel.criteria.matchDuration {
                    VStack(alignment: .leading) {
                        Text("Duration Tolerance: \(Int(viewModel.criteria.durationTolerance))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $viewModel.criteria.durationTolerance, in: 0...10, step: 1)
                    }
                }
            }
            
            Section("Audio Fingerprint") {
                Toggle("Enable Fingerprint Matching", isOn: $viewModel.criteria.matchFingerprint)
                
                if viewModel.criteria.matchFingerprint {
                    Picker("Sample Duration", selection: $viewModel.fingerprintSettings.sampleDuration) {
                        ForEach(FingerprintSettings.SampleDuration.allCases) { duration in
                            Text(duration.rawValue).tag(duration)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Similarity Threshold: \(Int(viewModel.fingerprintSettings.similarityThreshold * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $viewModel.fingerprintSettings.similarityThreshold, in: 0.5...1.0, step: 0.05)
                    }
                    
                    Text("Higher = stricter matching")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Auto-Selection") {
                Picker("Rule", selection: $viewModel.activeRule) {
                    ForEach(AutoSelectionRule.allCases) { rule in
                        Text(rule.rawValue).tag(rule)
                    }
                }
                .onChange(of: viewModel.activeRule) { _ in
                    viewModel.applySelectionRule()
                }
                
                Button("Apply Rule") {
                    viewModel.applySelectionRule()
                }
                .disabled(viewModel.duplicateGroups.isEmpty)
            }
            
            Section("Playback") {
                Toggle("Auto-Play on Select", isOn: $viewModel.autoPlayEnabled)
                
                if audioPlayer.isPlaying {
                    Button(action: {
                        viewModel.stopPlayback()
                    }) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                }
            }
            
            Section("Actions") {
                HStack {
                    Button("Scan Library") {
                        viewModel.scanLibrary()
                    }
                    .disabled(viewModel.isScanning)
                    
                    Button("Scan Folder...") {
                        selectFolder()
                    }
                    .disabled(viewModel.isScanning)
                    
                    if viewModel.isScanning {
                        ProgressView().controlSize(.small)
                    }
                }
                
                
                Button(role: .destructive, action: {
                    viewModel.showingDeleteConfirmation = true
                }) {
                    Text("Remove Selected")
                }
                .disabled(viewModel.duplicateGroups.isEmpty)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Filters")
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to scan for duplicate audio files"
        panel.prompt = "Scan"
        
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.scanFolder(at: url)
        }
    }
}
