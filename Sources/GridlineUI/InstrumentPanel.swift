import GridlineCore
import SwiftUI
import UniformTypeIdentifiers

struct InstrumentPanel: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INSTRUMENTE")
                .font(Theme.monoBold)
                .foregroundStyle(Theme.dim)
                .padding(12)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(state.song.instruments.indices, id: \.self) { index in
                        let instrument = state.song.instruments[index]
                        HStack {
                            Text(String(format: "%02d", index + 1)).foregroundStyle(Theme.dim)
                            Text(instrument.name).foregroundStyle(Theme.text).lineLimit(1)
                            Spacer()
                        }
                        .font(Theme.mono)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(index == state.selectedInstrument ? Theme.accent.opacity(0.18) : .clear)
                        .contentShape(Rectangle())
                        .onTapGesture { state.selectedInstrument = index }
                    }
                }
            }

            Divider()
            InstrumentEditor()
                .padding(12)
        }
        .background(Theme.panel)
    }
}

private struct InstrumentEditor: View {
    @EnvironmentObject private var state: AppState
    @State private var isImporting = false

    var body: some View {
        let index = state.selectedInstrument
        VStack(alignment: .leading, spacing: 10) {
            Button("Sample laden …") { isImporting = true }
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio]) { result in
                    switch result {
                    case .success(let url): state.importSample(from: url)
                    case .failure(let error): state.statusMessage = error.localizedDescription
                    }
                }
            LabeledSlider(title: "Lautstärke", value: $state.song.instruments[index].volume, range: 0...1)
            LabeledSlider(title: "Stimmung", value: $state.song.instruments[index].tune, range: -24...24)
            LabeledSlider(title: "Attack", value: $state.song.instruments[index].attack, range: 0.001...1)
            LabeledSlider(title: "Release", value: $state.song.instruments[index].release, range: 0.005...2)
            Toggle("Loop", isOn: $state.song.instruments[index].loop)
        }
        .font(.system(size: 11))
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).foregroundStyle(Theme.dim)
                Spacer()
                Text(String(format: "%.2f", value)).font(Theme.mono).foregroundStyle(Theme.text)
            }
            Slider(value: $value, in: range)
        }
    }
}
