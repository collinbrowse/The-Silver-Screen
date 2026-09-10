//
//  SectionHeader.swift
//  URBNFlicks
//

import SwiftUI

/// Section title with an optional trailing action (e.g. View All).
struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(DesignTypography.section)
                .foregroundStyle(DesignTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: DesignSpacing.sm)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(DesignTypography.chip.weight(.semibold))
                        .foregroundStyle(DesignTheme.accent)
                        .padding(.horizontal, DesignSpacing.sm)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionTitle)
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, DesignSpacing.lg)
    }
}
