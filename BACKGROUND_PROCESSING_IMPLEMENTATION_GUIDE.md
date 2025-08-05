# Background Processing Implementation Guide for iOS Apps

This guide provides a comprehensive walkthrough for implementing robust background processing in iOS applications, allowing long-running operations to continue when the app is backgrounded or minimized.

## Overview

The implementation uses a combination of:
- **UIApplication Background Tasks** - iOS system for extended background execution
- **Silent Audio Engine** - AVAudioEngine playing silent audio to maintain background execution
- **Reference Counting** - Managing multiple concurrent background operations
- **Timeout Management** - Preventing runaway background tasks

## Core Components

### 1. BackgroundTaskManager Class

The central component that manages all background processing functionality.

#### Key Features:
- **Singleton Pattern** - Single shared instance across the app
- **Thread Safety** - Uses dedicated DispatchQueue for state management
- **Reference Counting** - Tracks multiple concurrent operations
- **Automatic Cleanup** - Handles resource cleanup and timeout management

#### Core Properties:
```swift
private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
private var audioEngine: AVAudioEngine?
private var idleTimer: Timer?
private var hardTimeoutTimer: Timer?
private var activeCount = 0
private let queue = DispatchQueue(label: "BackgroundTaskManager", qos: .utility)
```

### 2. Silent Audio Engine

Uses AVAudioEngine to play silent audio, which keeps the app active in background.

#### Implementation Details:
- **Audio Category**: `.playback` with `.mixWithOthers` option
- **Silent Audio Node**: Generates silent audio buffers
- **Background Compatibility**: Allows background execution without interfering with other audio

### 3. Timeout Management

Two-tier timeout system for safety:
- **Idle Timeout**: 60 seconds of inactivity
- **Hard Timeout**: 5 minutes maximum execution time

## Implementation Steps

### Step 1: Create BackgroundTaskManager.swift

Create the main background task management class in your project:

**Location**: `YourApp/Backend/Observable/BackgroundTaskManager.swift`

**Key Methods**:
- `begin()` - Start background processing
- `end(force: Bool = false)` - End background processing
- `ping()` - Reset idle timer during active operations

### Step 2: Update Info.plist

Add required background capabilities to your app's Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>background-processing</string>
</array>
```

**Explanation**:
- `audio` - Enables background audio capability for silent audio engine
- `background-processing` - Enables general background processing

### Step 3: Integration Points

Identify and wrap long-running operations with background task management:

#### A. File Processing Operations
```swift
// Before
Task.detached {
    let handler = FileHandler(file: url)
    try await handler.process()
    completion(nil)
}

// After
Task.detached {
    BackgroundTaskManager.shared.begin()
    
    let handler = FileHandler(file: url)
    do {
        try await handler.process()
        BackgroundTaskManager.shared.ping() // Reset idle timer
        await MainActor.run {
            BackgroundTaskManager.shared.end()
            completion(nil)
        }
    } catch {
        await MainActor.run {
            BackgroundTaskManager.shared.end()
            completion(error)
        }
    }
}
```

#### B. Download Operations
```swift
// In URLSessionDownloadDelegate
func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, 
                didWriteData bytesWritten: Int64, totalBytesWritten: Int64, 
                totalBytesExpectedToWrite: Int64) {
    // Update progress
    DispatchQueue.main.async {
        download.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        BackgroundTaskManager.shared.ping() // Keep background task alive
    }
}
```

#### C. Server Operations
```swift
// Payload streaming
return req.fileio.streamFile(at: packageUrl.path) { result in
    BackgroundTaskManager.shared.end()
    self.updateStatus(.completed(result))
}
```

### Step 4: Best Practices

#### Reference Counting
- Multiple operations can call `begin()` simultaneously
- Each `begin()` call must have a corresponding `end()` call
- Background task only starts on first `begin()` and ends on last `end()`

#### Ping Mechanism
- Call `ping()` during active operations to reset idle timer
- Prevents premature timeout during long-running tasks
- Should be called at logical progress points

#### Error Handling
- Always call `end()` in error cases
- Use `defer` blocks or proper cleanup in catch blocks
- Consider using `end(force: true)` for emergency cleanup

## Technical Details

### Thread Safety
- Uses dedicated DispatchQueue for internal state management
- Main queue operations for UI-related tasks (timers, background tasks)
- Avoids actor isolation conflicts

### Audio Session Management
```swift
try AVAudioSession.sharedInstance().setCategory(
    .playback,
    mode: .default,
    options: [.mixWithOthers]
)
```

### Background Task Lifecycle
1. **Start**: `UIApplication.shared.beginBackgroundTask()`
2. **Monitor**: Track active operations with reference counting
3. **Maintain**: Silent audio engine keeps app active
4. **Timeout**: Automatic cleanup after idle/hard timeouts
5. **End**: `UIApplication.shared.endBackgroundTask()`

### Memory Management
- Weak references prevent retain cycles
- Proper cleanup in deinit
- Timer invalidation prevents memory leaks

## Common Integration Patterns

### Pattern 1: Simple Operation Wrapping
```swift
func performLongOperation() {
    BackgroundTaskManager.shared.begin()
    
    Task {
        defer { BackgroundTaskManager.shared.end() }
        
        // Your long-running operation here
        await performWork()
    }
}
```

### Pattern 2: Progress-Based Operations
```swift
func performProgressOperation() {
    BackgroundTaskManager.shared.begin()
    
    Task {
        defer { BackgroundTaskManager.shared.end() }
        
        for step in steps {
            await performStep(step)
            BackgroundTaskManager.shared.ping() // Reset timeout
        }
    }
}
```

### Pattern 3: Multiple Concurrent Operations
```swift
// Each operation independently manages background tasks
func startMultipleOperations() {
    for item in items {
        Task {
            BackgroundTaskManager.shared.begin()
            defer { BackgroundTaskManager.shared.end() }
            
            await processItem(item)
        }
    }
}
```

## Troubleshooting

### Common Issues:

1. **Background task not starting**
   - Check Info.plist background modes
   - Verify audio session setup
   - Ensure proper main queue execution

2. **Premature timeout**
   - Add more `ping()` calls during active operations
   - Check idle timeout duration (60 seconds default)
   - Verify reference counting logic

3. **Memory leaks**
   - Use weak references in closures
   - Invalidate timers properly
   - Check deinit cleanup

4. **Audio conflicts**
   - Use `.mixWithOthers` option
   - Handle audio session interruptions
   - Test with other audio apps

### Testing:
- Test with app backgrounding during operations
- Verify operations continue in background
- Check timeout behavior
- Test multiple concurrent operations
- Monitor memory usage and cleanup

## Performance Considerations

- Background tasks have limited execution time (typically 30 seconds, extended by audio)
- Silent audio extends background time but uses battery
- Use judiciously for truly necessary operations
- Consider user experience and battery impact

This implementation provides robust background processing while maintaining iOS best practices and system resource efficiency.

## Complete Code Examples

### BackgroundTaskManager.swift (Complete Implementation)

```swift
//
//  BackgroundTaskManager.swift
//  YourApp
//
//  Created by Developer on Date.
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

    private let logger = Logger(subsystem: "YourApp", category: "BackgroundTaskManager")

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

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "YourAppBackgroundTask") { [weak self] in
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
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
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
            try AVAudioSession.sharedInstance().setActive(false)
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
```

### Integration Example: File Processing

```swift
// Example: Wrapping file processing operations
enum FileProcessor {
    static func handlePackageFile(
        _ ipa: URL,
        completion: @escaping (Error?) -> Void
    ) {
        Task.detached {
            BackgroundTaskManager.shared.begin()

            let handler = FileHandler(file: ipa)

            do {
                try await handler.copy()
                BackgroundTaskManager.shared.ping()

                try await handler.extract()
                BackgroundTaskManager.shared.ping()

                try await handler.process()
                BackgroundTaskManager.shared.ping()

                try await handler.finalize()

                await MainActor.run {
                    BackgroundTaskManager.shared.end()
                    completion(nil)
                }
            } catch {
                await MainActor.run {
                    BackgroundTaskManager.shared.end()
                    completion(error)
                }
            }
        }
    }
}
```

### Integration Example: Download Manager

```swift
// Example: Download manager with background processing
class DownloadManager: NSObject, ObservableObject {
    // ... other properties

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let download = getDownload(for: downloadTask) else { return }

        DispatchQueue.main.async {
            download.progress = totalBytesExpectedToWrite > 0
                ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                : 0
            download.bytesDownloaded = totalBytesWritten
            download.totalBytes = totalBytesExpectedToWrite

            // Keep background task alive during download
            BackgroundTaskManager.shared.ping()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let download = getDownload(for: downloadTask) else { return }

        // Process downloaded file with background processing
        BackgroundTaskManager.shared.begin()

        Task {
            defer { BackgroundTaskManager.shared.end() }

            do {
                try await processDownloadedFile(at: location, for: download)
            } catch {
                print("Error processing downloaded file: \(error)")
            }
        }
    }
}
```

## Advanced Usage Patterns

### Pattern: Batch Operations with Progress Tracking

```swift
func processBatchOperations(_ items: [Item]) {
    BackgroundTaskManager.shared.begin()

    Task {
        defer { BackgroundTaskManager.shared.end() }

        for (index, item) in items.enumerated() {
            await processItem(item)

            // Update progress and ping
            let progress = Double(index + 1) / Double(items.count)
            await MainActor.run {
                updateProgress(progress)
            }
            BackgroundTaskManager.shared.ping()
        }
    }
}
```

### Pattern: Network Operations with Retry Logic

```swift
func performNetworkOperation(with retries: Int = 3) {
    BackgroundTaskManager.shared.begin()

    Task {
        defer { BackgroundTaskManager.shared.end() }

        var attempts = 0
        while attempts < retries {
            do {
                try await performNetworkCall()
                break // Success
            } catch {
                attempts += 1
                if attempts < retries {
                    BackgroundTaskManager.shared.ping()
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                } else {
                    throw error // Final attempt failed
                }
            }
        }
    }
}
```

## Testing and Validation

### Test Scenarios:
1. **Background Transition Test**: Start operation, background app, verify continuation
2. **Multiple Operations Test**: Start several operations simultaneously
3. **Timeout Test**: Let operation idle to test timeout behavior
4. **Memory Test**: Monitor memory usage during long operations
5. **Audio Conflict Test**: Test with music/other audio apps

### Debugging Tips:
- Use Console.app to view system logs
- Monitor background task identifiers
- Check audio session state
- Verify timer invalidation
- Test on physical devices (simulators may behave differently)

This comprehensive guide provides everything needed to implement robust background processing in iOS applications.
