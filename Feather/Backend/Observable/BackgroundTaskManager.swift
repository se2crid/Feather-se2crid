//
//  BackgroundTaskManager.swift
//  Feather
//
//  Created by se2crid on 05.08.2025.
//

import UIKit
import AVFoundation
import OSLog

final class BackgroundTaskManager: ObservableObject {
	static let shared = BackgroundTaskManager()

	private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
	private var audioEngine: AVAudioEngine?
	private var idleTimer: Timer?
	private var hardTimeoutTimer: Timer?
	private var activeCount = 0
	private let queue = DispatchQueue(label: "BackgroundTaskManager", qos: .utility)

	private let logger = Logger(subsystem: "Feather", category: "BackgroundTaskManager")

	private init() {}

	func begin() {
		queue.async { [weak self] in
			guard let self = self else { return }

			self.logger.info("Background task begin requested (activeCount: \(self.activeCount))")

			if self.activeCount == 0 {
				DispatchQueue.main.async {
					self.startBackgroundTask()
					self.startSilentAudioEngine()
					self.startHardTimeout()
				}
			}

			self.activeCount += 1

			DispatchQueue.main.async {
				self.resetIdleTimer()
			}
		}
	}

	func end(force: Bool = false) {
		queue.async { [weak self] in
			guard let self = self else { return }

			self.logger.info("Background task end requested (force: \(force), activeCount: \(self.activeCount))")

			if force {
				DispatchQueue.main.async {
					self.cleanup()
				}
			} else {
				self.activeCount = max(0, self.activeCount - 1)
				if self.activeCount == 0 {
					DispatchQueue.main.async {
						self.cleanup()
					}
				}
			}
		}
	}

	func ping() {
		queue.async { [weak self] in
			guard let self = self else { return }

			guard self.activeCount > 0 else {
				self.logger.debug("Ping ignored: no active tasks")
				return
			}

			self.logger.debug("Background task ping received")

			DispatchQueue.main.async {
				self.resetIdleTimer()
			}
		}
	}
	
	private func startBackgroundTask() {
		guard backgroundTaskID == .invalid else { return }

		backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "FeatherBackgroundTask") { [weak self] in
			self?.logger.warning("Background task expired, forcing cleanup")
			self?.end(force: true)
		}

		logger.info("Background task started (ID: \(self.backgroundTaskID.rawValue))")
	}

	private func startSilentAudioEngine() {
		guard audioEngine == nil else { return }

		let engine = AVAudioEngine()
		let output = engine.outputNode
		let format = output.inputFormat(forBus: 0)

		let silentNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
			let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
			for buffer in ablPointer {
				memset(buffer.mData, 0, Int(buffer.mDataByteSize))
			}
			return noErr
		}

		engine.attach(silentNode)
		engine.connect(silentNode, to: output, format: format)

		do {
			// Use ambient so the app's silent audio mixes with other apps' audio and does not interrupt them.
			try AVAudioSession.sharedInstance().setCategory(
				.ambient,
				mode: .default,
				options: [.mixWithOthers]
			)
			try AVAudioSession.sharedInstance().setActive(true)
			try engine.start()

			self.audioEngine = engine
			logger.info("Silent audio engine started successfully")
		} catch {
			logger.error("Failed to start silent audio engine: \(error.localizedDescription)")
		}
	}

	private func stopSilentAudioEngine() {
		audioEngine?.stop()
		audioEngine = nil

		do {
			// Deactivate and notify others so external audio can resume when we stop.
			try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
		} catch {
			logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
		}

		logger.info("Silent audio engine stopped")
	}

	private func resetIdleTimer() {
		idleTimer?.invalidate()
		idleTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
			self?.logger.info("Idle timeout reached, ending background task")
			self?.end()
		}
	}

	private func startHardTimeout() {
		hardTimeoutTimer?.invalidate()
		hardTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: false) { [weak self] _ in
			self?.logger.warning("Hard timeout reached, forcing end of background task")
			self?.end(force: true)
		}
	}

	private func cleanup() {
		queue.async { [weak self] in
			guard let self = self else { return }
			self.activeCount = 0
		}

		logger.info("Cleaning up background task resources")

		stopSilentAudioEngine()

		idleTimer?.invalidate()
		idleTimer = nil

		hardTimeoutTimer?.invalidate()
		hardTimeoutTimer = nil

		if backgroundTaskID != .invalid {
			UIApplication.shared.endBackgroundTask(backgroundTaskID)
			backgroundTaskID = .invalid
			logger.info("Background task ended")
		}
	}

	deinit {
		DispatchQueue.main.async { [weak self] in
			self?.cleanup()
		}
	}
}
