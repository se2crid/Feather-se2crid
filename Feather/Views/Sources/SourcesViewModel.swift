//
//  SourcesViewModel.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

import Foundation
import AltSourceKit
import SwiftUI
import NimbleJSON
import OSLog

// MARK: - Class
final class SourcesViewModel: ObservableObject {
	static let shared = SourcesViewModel()
	
	typealias RepositoryDataHandler = Result<ASRepository, Error>
	
	private let _dataService = NBFetchService()
	
	var isFinished = true
	@Published var sources: [AltSource: ASRepository] = [:]
	@Published var lastUpdated: [String: Date] = [:]
	
	private var autoRefreshTimer: Timer?
	
	init() {
		_setupAutoRefresh()
	}
	
	deinit {
		autoRefreshTimer?.invalidate()
	}
	
	func fetchSources(_ sources: FetchedResults<AltSource>, refresh: Bool = false, batchSize: Int = 4) async {
		guard isFinished else { return }
		
		// check if sources to be fetched are the same as before, if yes, return
		// also skip check if refresh is true
		if !refresh, sources.allSatisfy({ self.sources[$0] != nil }) { return }
		
		// isfinished is used to prevent multiple fetches at the same time
		isFinished = false
		defer { isFinished = true }
		
		await MainActor.run {
			self.sources = [:]
		}
		
		let sourcesArray = Array(sources)
		
		for startIndex in stride(from: 0, to: sourcesArray.count, by: batchSize) {
			let endIndex = min(startIndex + batchSize, sourcesArray.count)
			let batch = sourcesArray[startIndex..<endIndex]
			
			let batchResults = await withTaskGroup(of: (AltSource, ASRepository?).self, returning: [AltSource: ASRepository].self) { group in
				for source in batch {
					group.addTask {
						guard let url = source.sourceURL else {
							return (source, nil)
						}
						
						return await withCheckedContinuation { continuation in
							self._dataService.fetch(from: url) { (result: RepositoryDataHandler) in
								switch result {
								case .success(let repo):
									continuation.resume(returning: (source, repo))
								case .failure(_):
									continuation.resume(returning: (source, nil))
								}
							}
						}
					}
				}
				
				var results = [AltSource: ASRepository]()
				for await (source, repo) in group {
					if let repo {
						results[source] = repo
					}
				}
				return results
			}
			
			await MainActor.run {
				for (source, repo) in batchResults {
					self.sources[source] = repo
					// Update the last updated time for this source
					if let identifier = source.identifier {
						self.lastUpdated[identifier] = Date()
					}
				}
			}
		}
	}
	
	/// Setup automatic refresh timer
	private func _setupAutoRefresh() {
		// Auto-refresh every 4 hours if enabled in settings
		let refreshInterval: TimeInterval = 4 * 60 * 60 // 4 hours
		
		autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
			guard let self = self else { return }
			
			// Only auto-refresh if enabled in settings
			let autoRefreshEnabled = UserDefaults.standard.object(forKey: "Feather.autoRefreshRepositories") as? Bool ?? true
			guard autoRefreshEnabled else { return }
			
			Task {
				Logger.misc.info("Auto-refreshing repositories...")
				await self.refreshAllRepositories()
				
				await MainActor.run {
					UserDefaults.standard.set(Date(), forKey: "Feather.lastAutoRepositoryRefresh")
				}
			}
		}
	}
	
	/// Manually trigger refresh for all repositories
	func refreshAllRepositories() async {
		let sources = Storage.shared.getSources()
		guard !sources.isEmpty else { return }
		
		Logger.misc.info("Manually refreshing \(sources.count) repositories")
		
		// Simulate FetchedResults by creating an array and processing each source
		await withTaskGroup(of: Void.self) { group in
			for source in sources {
				group.addTask {
					guard let url = source.sourceURL else { return }
					
					await withCheckedContinuation { continuation in
						self._dataService.fetch(from: url) { (result: RepositoryDataHandler) in
							switch result {
							case .success(let repo):
								Task { @MainActor in
									self.sources[source] = repo
									if let identifier = source.identifier {
										self.lastUpdated[identifier] = Date()
									}
								}
							case .failure(let error):
								Logger.misc.error("Failed to refresh repository \(url): \(error.localizedDescription)")
							}
							continuation.resume()
						}
					}
				}
			}
		}
		
		// Store the refresh time
		await MainActor.run {
			UserDefaults.standard.set(Date(), forKey: "Feather.lastManualRepositoryUpdate")
		}
	}
}
