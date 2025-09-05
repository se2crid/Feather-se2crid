//
//  RepositorySettingsView.swift
//  Feather
//
//  Created by Assistant on 5.09.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct RepositorySettingsView: View {
	@AppStorage("Feather.autoRefreshRepositories") private var autoRefreshEnabled = true
	@AppStorage("Feather.autoRefreshOnLaunch") private var autoRefreshOnLaunch = true
	@State private var _lastAutoRefresh: Date?
	@State private var _lastManualRefresh: Date?
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Repository Settings"), displayMode: .inline) {
			Form {
				NBSection(.localized("Automatic Updates")) {
					Toggle(.localized("Auto-refresh repositories"), isOn: $autoRefreshEnabled)
					
					Toggle(.localized("Refresh on app launch"), isOn: $autoRefreshOnLaunch)
				} footer: {
					Text(.localized("When enabled, repositories will be automatically refreshed in the background to keep your app catalog up to date."))
				}
				
				NBSection(.localized("Update Status")) {
					if let lastAuto = _lastAutoRefresh {
						HStack {
							Text(.localized("Last automatic update"))
							Spacer()
							Text(lastAuto.formatted(.relative(presentation: .named)))
								.foregroundColor(.secondary)
						}
					}
					
					if let lastManual = _lastManualRefresh {
						HStack {
							Text(.localized("Last manual update"))
							Spacer()
							Text(lastManual.formatted(.relative(presentation: .named)))
								.foregroundColor(.secondary)
						}
					}
					
					Button(.localized("Update All Repositories Now"), systemImage: "arrow.clockwise") {
						_updateAllRepositories()
					}
				} footer: {
					Text(.localized("You can manually trigger a refresh of all repositories or check when they were last updated."))
				}
				
				NBSection(.localized("Update Frequency")) {
					Text(.localized("Repositories are automatically refreshed every 4 hours when auto-refresh is enabled."))
						.foregroundColor(.secondary)
				} footer: {
					Text(.localized("This helps ensure you always have access to the latest app versions and new releases."))
				}
			}
		}
		.onAppear {
			_loadUpdateDates()
		}
	}
	
	private func _loadUpdateDates() {
		_lastAutoRefresh = UserDefaults.standard.object(forKey: "Feather.lastAutoRepositoryRefresh") as? Date
		_lastManualRefresh = UserDefaults.standard.object(forKey: "Feather.lastManualRepositoryUpdate") as? Date
	}
	
	private func _updateAllRepositories() {
		Task {
			await SourcesViewModel.shared.refreshAllRepositories()
			_loadUpdateDates()
		}
	}
}