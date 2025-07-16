//
//  SigningAppAlternativeIconView.swift
//  Feather
//
//  Created by samara on 18.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningAlternativeIconView: View {
	@Environment(\.dismiss) var dismiss
	
	@State private var _alternateIcons: [(name: String, path: String)] = []
	
	var app: AppInfoPresentable
	@Binding var appIcon: UIImage?
	@Binding var isModifing: Bool
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Alternative Icons"), displayMode: .inline) {
			VStack {
				if !_alternateIcons.isEmpty {
					NBSection(.localized("Choose an Icon"), systemName: "app.dashed") {
						NBGrid {
							ForEach(_alternateIcons, id: \.name) { icon in
								Button {
									appIcon = _iconUrl(icon.path)
									dismiss()
								} label: {
									_iconGridCell(icon)
								}
								.disabled(!isModifing)
							}
						}
					}
				} else {
					Spacer()
					Text(.localized("No Icons Found."))
						.font(.footnote)
						.foregroundColor(.disabled())
					Spacer()
				}
			}
			.onAppear(perform: _loadAlternateIcons)
			.toolbar {
				if isModifing {
					NBToolbarButton(role: .close)
				}
			}
		}
	}
}

// MARK: - Extension: View
extension SigningAlternativeIconView {
	@ViewBuilder
	private func _iconGridCell(_ icon: (name: String, path: String)) -> some View {
		VStack(spacing: 8) {
			ZStack {
				if let image = _iconUrl(icon.path) {
					Image(uiImage: image)
						.appIconStyle(size: 56)
						.overlay(
							RoundedRectangle(cornerRadius: 12)
								.stroke(appIcon?.pngData() == image.pngData() ? Color.accentColor : Color.clear, lineWidth: 3)
						)
				}
			}
			Text(icon.name)
				.font(.caption)
				.foregroundColor(.primary)
		}
		.padding(8)
	}
	
	
	private func _iconUrl(_ path: String) -> UIImage? {
		guard let app = Storage.shared.getAppDirectory(for: app) else {
			return nil
		}
		return UIImage(contentsOfFile: app.appendingPathComponent(path).relativePath)?.resizeToSquare()
	}
	
	private func _loadAlternateIcons() {
		guard let appDirectory = Storage.shared.getAppDirectory(for: app) else { return }
		
		let infoPlistPath = appDirectory.appendingPathComponent("Info.plist")
		guard
			let infoPlist = NSDictionary(contentsOf: infoPlistPath),
			let iconDict = infoPlist["CFBundleIcons"] as? [String: Any],
			let alternateIconsDict = iconDict["CFBundleAlternateIcons"] as? [String: [String: Any]]
		else {
			return
		}
		
		_alternateIcons = alternateIconsDict.compactMap { (name, details) in
			if let files = details["CFBundleIconFiles"] as? [String], let path = files.first {
				return (name, path)
			}
			return nil
		}
	}
}
