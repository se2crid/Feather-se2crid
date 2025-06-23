//
//  ContentView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - View
struct LibraryView: View {
	@StateObject var downloadManager = DownloadManager.shared
	
	@State private var _selectedInfoAppPresenting: AnyApp?
	@State private var _selectedSigningAppPresenting: AnyApp?
	@State private var _selectedInstallAppPresenting: AnyApp?
	@State private var _isImportingPresenting = false
	@State private var _isDownloadingPresenting = false
	@State private var _alertDownloadString: String = "" // for _isDownloadingPresenting
	@State private var _isAutoSigning = false
	
	@State private var _searchText = ""
	@State private var _selectedScope: Scope = .all
	
	@Namespace private var _namespace
	
	// horror
	private func filteredAndSortedApps<T>(from apps: FetchedResults<T>) -> [T] where T: NSManagedObject {
		apps.filter {
			_searchText.isEmpty ||
			(($0.value(forKey: "name") as? String)?.localizedCaseInsensitiveContains(_searchText) ?? false)
		}
	}
	
	private var _filteredSignedApps: [Signed] {
		filteredAndSortedApps(from: _signedApps)
	}
	
	private var _filteredImportedApps: [Imported] {
		filteredAndSortedApps(from: _importedApps)
	}
	
	// MARK: Fetch
	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>
	
	@FetchRequest(
		entity: Imported.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)],
		animation: .snappy
	) private var _importedApps: FetchedResults<Imported>
	
	// MARK: Body
    var body: some View {
		NBNavigationView(.localized("Library")) {
			NBListAdaptable {
				if
					!_filteredSignedApps.isEmpty ||
					!_filteredImportedApps.isEmpty
				{
					if
						_selectedScope == .all ||
						_selectedScope == .signed
					{
						NBSection(
							.localized("Signed"),
							secondary: _filteredSignedApps.count.description
						) {
							ForEach(_filteredSignedApps, id: \.uuid) { app in
								LibraryCellView(
									app: app,
									selectedInfoAppPresenting: $_selectedInfoAppPresenting,
									selectedSigningAppPresenting: $_selectedSigningAppPresenting,
									selectedInstallAppPresenting: $_selectedInstallAppPresenting
								)
								.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
							}
						}
					}
					
					if
						_selectedScope == .all ||
							_selectedScope == .imported
					{
						NBSection(
							.localized("Imported"),
							secondary: _filteredImportedApps.count.description
						) {
							ForEach(_filteredImportedApps, id: \.uuid) { app in
								LibraryCellView(
									app: app,
									selectedInfoAppPresenting: $_selectedInfoAppPresenting,
									selectedSigningAppPresenting: $_selectedSigningAppPresenting,
									selectedInstallAppPresenting: $_selectedInstallAppPresenting
								)
								.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
							}
						}
					}
				}
			}
			.searchable(text: $_searchText, placement: .platform())
			.compatSearchScopes($_selectedScope) {
				ForEach(Scope.allCases, id: \.displayName) { scope in
					Text(scope.displayName).tag(scope)
				}
			}
			.scrollDismissesKeyboard(.interactively)
			.overlay {
				if
					_filteredSignedApps.isEmpty,
					_filteredImportedApps.isEmpty
				{
					if #available(iOS 17, *) {
						ContentUnavailableView {
							Label(.localized("No Apps"), systemImage: "questionmark.app.fill")
						} description: {
							Text(.localized("Get started by importing your first IPA file."))
						} actions: {
							Menu {
								_importActions()
							} label: {
								NBButton(.localized("Import"), style: .text)
							}
						}
					}
				}
			}
			.toolbar {
				NBToolbarMenu(
					systemImage: "plus",
					style: .icon,
					placement: .topBarTrailing
				) {
					_importActions()
				}
			}
			.sheet(item: $_selectedInfoAppPresenting) { app in
				LibraryInfoView(app: app.base)
			}
			.sheet(item: $_selectedInstallAppPresenting) { app in
				InstallPreviewView(app: app.base, isSharing: app.archive)
					.presentationDetents([.height(200)])
					.presentationDragIndicator(.visible)
					.compatPresentationRadius(21)
			}
			.fullScreenCover(item: _signingCoverBinding) { app in
				SigningView(app: app.base)
					.compatNavigationTransition(id: app.base.uuid ?? "", ns: _namespace)
			}
			.onChange(of: _selectedSigningAppPresenting?.id) { _ in
				guard let anyApp = _selectedSigningAppPresenting else { return }
				let options = OptionsManager.shared.options
				if options.skipSigningScreen, !_isAutoSigning {
					// Intercept and auto sign without presenting UI
					_selectedSigningAppPresenting = nil
					_isAutoSigning = true
					_autoSignAndMaybeInstall(app: anyApp.base, options: options) {
						_isAutoSigning = false
					}
				}
			}
			.onChange(of: _selectedInstallAppPresenting?.id) { _ in
				guard let anyApp = _selectedInstallAppPresenting else { return }
				let options = OptionsManager.shared.options
				// If attempting to install an unsigned app and skipping signing UI is enabled, auto sign & install
				if !anyApp.base.isSigned, options.skipSigningScreen, !_isAutoSigning {
					_selectedInstallAppPresenting = nil
					_isAutoSigning = true
					_autoSignAndMaybeInstall(app: anyApp.base, options: options) {
						_isAutoSigning = false
					}
				}
			}
			.sheet(isPresented: $_isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.ipa, .tipa],
					allowsMultipleSelection: true,
					onDocumentsPicked: { urls in
						guard !urls.isEmpty else { return }
						
						for url in urls {
							let id = "FeatherManualDownload_\(UUID().uuidString)"
							let dl = downloadManager.startArchive(from: url, id: id)
							try? downloadManager.handlePachageFile(url: url, dl: dl)
						}
					}
				)
				.ignoresSafeArea()
			}
			.alert(.localized("Import from URL"), isPresented: $_isDownloadingPresenting) {
				TextField(.localized("URL"), text: $_alertDownloadString)
					.textInputAutocapitalization(.never)
				Button(.localized("Cancel"), role: .cancel) {
					_alertDownloadString = ""
				}
				Button(.localized("OK")) {
					if let url = URL(string: _alertDownloadString) {
						_ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(UUID().uuidString)")
					}
				}
			}
        }
    }
}

// MARK: - Extension: View
extension LibraryView {
	@ViewBuilder
	private func _importActions() -> some View {
		Button(.localized("Import from Files"), systemImage: "folder") {
			_isImportingPresenting = true
		}
		Button(.localized("Import from URL"), systemImage: "globe") {
			_isDownloadingPresenting = true
		}
	}
}

// MARK: - Extension: View (Sort)
extension LibraryView {
	enum Scope: CaseIterable {
		case all
		case signed
		case imported
		
		var displayName: String {
			switch self {
			case .all: return .localized("All")
			case .signed: return .localized("Signed")
			case .imported: return .localized("Imported")
			}
		}
	}
}

// MARK: - Auto Sign Helper
extension LibraryView {
	private func _autoSignAndMaybeInstall(app: AppInfoPresentable, options: Options, completion: @escaping () -> Void) {
		let context = Storage.shared.context
		// Fetch certificates ordered by date
		let fetch: NSFetchRequest<CertificatePair> = CertificatePair.fetchRequest()
		fetch.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
		let certificates = (try? context.fetch(fetch)) ?? []
		let selectedIndex = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		let cert: CertificatePair? = certificates.indices.contains(selectedIndex) ? certificates[selectedIndex] : nil

		FR.signPackageFile(app, using: options, icon: nil, certificate: cert) { error in
			if let error {
				// present error alert
				UIAlertController.showAlertWithOk(title: .localized("Signing"), message: error.localizedDescription)
				completion()
				return
			}

			// Delete original imported app if option set
			if options.post_deleteAppAfterSigned, !app.isSigned {
				Storage.shared.deleteApp(for: app)
			}

			if options.post_installAppAfterSigned {
				// Fetch latest signed app and trigger installer
				let req: NSFetchRequest<Signed> = Signed.fetchRequest()
				req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
				req.fetchLimit = 1
				if let latest = (try? context.fetch(req))?.first {
					DispatchQueue.main.async {
						_selectedInstallAppPresenting = AnyApp(base: latest)
						completion()
					}
				} else {
					completion()
				}
			} else {
				completion()
			}
		}
	}
}

// Binding used to decide whether to present the manual signing UI
extension LibraryView {
	private var _signingCoverBinding: Binding<AnyApp?> {
		Binding<AnyApp?> {
			let skip = OptionsManager.shared.options.skipSigningScreen
			return skip ? nil : _selectedSigningAppPresenting
		} set: { newValue in
			_selectedSigningAppPresenting = newValue
		}
	}
}
