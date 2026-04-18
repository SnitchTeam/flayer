import Foundation
import CoreServices

@MainActor
final class FolderWatcher {
    // FSEventStream callbacks are dispatched to the main queue (see
    // FSEventStreamSetDispatchQueue below), so access stays on the main
    // actor — no need for a `nonisolated(unsafe)` escape hatch.
    private var stream: FSEventStreamRef?
    private var onChanged: (() -> Void)?
    private var debounceTask: Task<Void, Never>?

    func watch(folders: [String], onChange: @escaping () -> Void) {
        stop()
        guard !folders.isEmpty else { return }
        onChanged = onChange

        let paths = folders as CFArray
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            Task { @MainActor in
                watcher.debouncedNotify()
            }
        }

        stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )

        if let stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
        onChanged = nil
    }

    private func debouncedNotify() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            onChanged?()
        }
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            debounceTask?.cancel()
            if let stream {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
            }
        }
    }
}
