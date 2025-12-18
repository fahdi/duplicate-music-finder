import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: AppViewModel
    
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
            
            Section("Actions") {
                Button(action: {
                    viewModel.scanLibrary()
                }) {
                    if viewModel.isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Scan Library")
                    }
                }
                .disabled(viewModel.isScanning)
                
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
}
