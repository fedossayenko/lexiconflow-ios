//
//  StudyEmptyView.swift
//  LexiconFlow
//
//  Shown when no cards are due for review
//

import SwiftUI

struct StudyEmptyView: View {
    let mode: StudyMode
    let onSwitchMode: (StudyMode) -> Void

    var body: some View {
        ContentUnavailableView {
            Label("All caught up!", systemImage: "checkmark.circle.fill")
        } description: {
            Text(modeDescription)
        } actions: {
            if mode == .scheduled {
                Button("Switch to Cram Mode") {
                    onSwitchMode(.cram)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Switch to Cram Mode")
                .accessibilityHint("Practice all cards regardless of due date")
            } else {
                Button("Switch to Scheduled Mode") {
                    onSwitchMode(.scheduled)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Switch to Scheduled Mode")
                .accessibilityHint("Review only cards that are due")
            }
        }
    }

    private var modeDescription: String {
        switch mode {
        case .scheduled:
            return "No cards are due for review right now. Check back later or switch to Cram mode to practice."
        case .cram:
            return "No cards available for cram. Add some cards to your decks first."
        }
    }
}

#Preview {
    NavigationStack {
        StudyEmptyView(mode: .scheduled) { _ in }
    }
}
