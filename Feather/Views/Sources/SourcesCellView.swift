//
//  SourcesCellView.swift
//  Feather
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import NimbleViews
import NukeUI

// MARK: - View
struct SourcesCellView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@ObservedObject var viewModel = SourcesViewModel.shared
	
	var source: AltSource
	
	// MARK: Body
	var body: some View {
		let isRegular = horizontalSizeClass != .compact
		let lastUpdatedText = _getLastUpdatedText()
		
		VStack(alignment: .leading, spacing: 0) {
			FRIconCellView(
				title: source.name ?? .localized("Unknown"),
				subtitle: source.sourceURL?.absoluteString ?? "",
				iconUrl: source.iconURL
			)
			
			if !lastUpdatedText.isEmpty {
				HStack {
					Text(.localized("Updated: \(lastUpdatedText)"))
						.font(.caption2)
						.foregroundColor(.secondary)
					Spacer()
				}
				.padding(.leading, 74) // Align with subtitle text
				.padding(.top, 2)
			}
		}
		.padding(isRegular ? 12 : 0)
		.background(
			isRegular
			? RoundedRectangle(cornerRadius: 18, style: .continuous)
				.fill(Color(.quaternarySystemFill))
			: nil
		)
		.swipeActions {
			_actions(for: source)
			_contextActions(for: source)
		}
		.contextMenu {
			_contextActions(for: source)
			Divider()
			_actions(for: source)
		}
	}
	
	private func _getLastUpdatedText() -> String {
		guard let identifier = source.identifier,
			  let lastUpdated = viewModel.lastUpdated[identifier] else {
			return ""
		}
		
		let formatter = RelativeDateTimeFormatter()
		formatter.unitsStyle = .short
		return formatter.localizedString(for: lastUpdated, relativeTo: Date())
	}
}

// MARK: - Extension: View
extension SourcesCellView {
	@ViewBuilder
	private func _actions(for source: AltSource) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteSource(for: source)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
		Button(.localized("Copy"), systemImage: "doc.on.clipboard") {
			UIPasteboard.general.string = source.sourceURL?.absoluteString
		}
	}
}
