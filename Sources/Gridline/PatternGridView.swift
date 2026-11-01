import GridlineCore
import SwiftUI

struct PatternGridView: View {
    @EnvironmentObject private var state: AppState

    private let rowNumberWidth: CGFloat = 44
    private let cellWidth: CGFloat = 150
    private let rowHeight: CGFloat = 20

    var body: some View {
        let pattern = state.currentPattern
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section(header: header) {
                        ForEach(0..<pattern.length, id: \.self) { stepIndex in
                            row(stepIndex, pattern: pattern)
                                .id(stepIndex)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .onChange(of: state.cursorStep) { _, step in
                proxy.scrollTo(step)
            }
            .onChange(of: state.playhead) { _, step in
                if state.isPlaying, step >= 0 { proxy.scrollTo(step) }
            }
        }
        .background(Theme.background)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("").frame(width: rowNumberWidth)
            ForEach(0..<Song.trackCount, id: \.self) { track in
                Text("SPUR \(track + 1)")
                    .font(Theme.monoBold)
                    .foregroundStyle(track == state.cursorTrack ? Theme.accent : Theme.dim)
                    .frame(width: cellWidth, height: rowHeight + 6)
            }
        }
        .background(Theme.panel)
    }

    private func row(_ stepIndex: Int, pattern: Pattern) -> some View {
        HStack(spacing: 0) {
            Text(String(format: "%03d", stepIndex))
                .font(Theme.mono)
                .foregroundStyle(stepIndex % 4 == 0 ? Theme.text : Theme.dim)
                .frame(width: rowNumberWidth)
            ForEach(0..<Song.trackCount, id: \.self) { track in
                StepCell(step: pattern[track, stepIndex],
                         isCursor: track == state.cursorTrack && stepIndex == state.cursorStep)
                    .frame(width: cellWidth, height: rowHeight)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        state.cursorTrack = track
                        state.cursorStep = stepIndex
                    }
            }
        }
        .background(rowBackground(stepIndex))
    }

    private func rowBackground(_ stepIndex: Int) -> Color {
        if stepIndex == state.playhead { return Theme.playhead }
        if stepIndex % 16 == 0 { return Theme.barRow }
        if stepIndex % 4 == 0 { return Theme.beatRow }
        return .clear
    }
}

struct StepCell: View {
    let step: Step
    let isCursor: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(StepFormatter.note(step)).foregroundStyle(step.note == .empty ? Theme.dim : Theme.text)
            Text(StepFormatter.instrument(step)).foregroundStyle(step.instrument == nil ? Theme.dim : Theme.accent)
            Text(StepFormatter.volume(step)).foregroundStyle(step.volume == nil ? Theme.dim : Theme.text)
            Text(StepFormatter.effect(step.fx1)).foregroundStyle(step.fx1 == nil ? Theme.dim : Theme.cursor)
        }
        .font(Theme.mono)
        .padding(.horizontal, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(isCursor ? Theme.cursor : .clear, lineWidth: 1.5)
        )
    }
}
