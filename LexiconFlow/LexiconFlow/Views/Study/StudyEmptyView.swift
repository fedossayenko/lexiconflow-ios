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
            Label(modeTitle, systemImage: modeIcon)
        } description: {
            Text(modeDescription)
        } actions: {
            modeSwitchButtons
        }
    }

    private var modeDescription: String {
        switch mode {
        case .learning:
            return "You've learned all your new cards. Add more cards to your decks or switch to Scheduled mode."
        case .scheduled:
            return "No cards are due for review right now. Check back later or switch to Learn New mode."
        }
    }

    private var modeTitle: String {
        switch mode {
        case .learning:
            return "No new cards"
        case .scheduled:
            return "All caught up!"
        }
    }

    private var modeIcon: String {
        switch mode {
        case .learning:
            return "plus.circle"
        case .scheduled:
            return "checkmark.circle.fill"
        }
    }

    @ViewBuilder
    private var modeSwitchButtons: some View {
        switch mode {
        case .learning:
            Button("Switch to Scheduled Mode") {
                onSwitchMode(.scheduled)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Switch to Scheduled Mode")
            .accessibilityHint("Review only cards that are due")
        case .scheduled:
            Button("Learn New") {
                onSwitchMode(.learning)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Switch to Learning Mode")
            .accessibilityHint("Learn new cards for the first time")
        }
    }
}

#Preview {
    NavigationStack {
        StudyEmptyView(mode: .scheduled) { _ in }
    }
}
