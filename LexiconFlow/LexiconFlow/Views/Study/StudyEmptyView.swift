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
            return "You've learned all your new cards. Add more cards to your decks or switch to Scheduled or Cram mode."
        case .scheduled:
            return "No cards are due for review right now. Check back later or switch to Learn New or Cram mode."
        case .cram:
            return "No cards available for cram. Add some cards to your decks first."
        }
    }

    private var modeTitle: String {
        switch mode {
        case .learning:
            return "No new cards"
        case .scheduled:
            return "All caught up!"
        case .cram:
            return "No cards available"
        }
    }

    private var modeIcon: String {
        switch mode {
        case .learning:
            return "plus.circle"
        case .scheduled:
            return "checkmark.circle.fill"
        case .cram:
            return "tray"
        }
    }

    @ViewBuilder
    private var modeSwitchButtons: some View {
        switch mode {
        case .learning:
            VStack(spacing: 12) {
                Button("Switch to Scheduled Mode") {
                    onSwitchMode(.scheduled)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Switch to Scheduled Mode")
                .accessibilityHint("Review only cards that are due")
                Button("Switch to Cram Mode") {
                    onSwitchMode(.cram)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Switch to Cram Mode")
                .accessibilityHint("Practice all cards regardless of due date")
            }
        case .scheduled:
            HStack(spacing: 12) {
                Button("Learn New") {
                    onSwitchMode(.learning)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Switch to Learning Mode")
                .accessibilityHint("Learn new cards for the first time")
                Button("Switch to Cram Mode") {
                    onSwitchMode(.cram)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Switch to Cram Mode")
                .accessibilityHint("Practice all cards regardless of due date")
            }
        case .cram:
            HStack(spacing: 12) {
                Button("Learn New") {
                    onSwitchMode(.learning)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Switch to Learning Mode")
                .accessibilityHint("Learn new cards for the first time")
                Button("Switch to Scheduled Mode") {
                    onSwitchMode(.scheduled)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Switch to Scheduled Mode")
                .accessibilityHint("Review only cards that are due")
            }
        }
    }
}

#Preview {
    NavigationStack {
        StudyEmptyView(mode: .scheduled) { _ in }
    }
}
