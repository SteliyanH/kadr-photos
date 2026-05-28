import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(PhotosUI)

// MARK: - AsyncResultsSink

/// Internal sink that owns an `AsyncStream<PhotoPickerResult>` continuation and a
/// signal continuation that fires once when the picker first delivers results.
/// Held as a reference so both the `PhotoPicker` view and the consumer `Task`
/// observe the same continuation across SwiftUI re-evaluations.
internal final class AsyncResultsSink: @unchecked Sendable {
    let stream: AsyncStream<PhotoPickerResult>
    private let continuation: AsyncStream<PhotoPickerResult>.Continuation

    init() {
        var capturedContinuation: AsyncStream<PhotoPickerResult>.Continuation!
        self.stream = AsyncStream<PhotoPickerResult> { cont in
            capturedContinuation = cont
        }
        self.continuation = capturedContinuation
    }

    func deliver(_ results: [PhotoPickerResult]) {
        for result in results {
            continuation.yield(result)
        }
        continuation.finish()
    }
}

// MARK: - Delivery dispatch

@available(iOS 16, macOS 13, visionOS 1, *)
extension PhotoPicker {

    @MainActor
    internal static func deliver(_ results: [PhotoPickerResult], via delivery: Delivery) {
        switch delivery {
        case .binding(let binding):
            binding.wrappedValue = results
        case .asyncStream(let sink):
            sink.deliver(results)
        }
    }
}

// MARK: - iOS 17 AsyncSequence overload

@available(iOS 17, macOS 14, visionOS 1, *)
extension PhotoPicker {

    /// iOS 17 / macOS 14 overload — instead of dumping the final results into a
    /// binding, exposes each picked item as an element of an `AsyncStream`. The
    /// closure receives the stream synchronously when the view is created; iterate
    /// with `for await`. The stream finishes when the user dismisses the picker.
    ///
    /// The iOS 16 closure path stays for the platform floor — pick this overload
    /// when iOS 17 is the deployment minimum.
    ///
    /// ```swift
    /// PhotoPicker(configuration: .init(selectionLimit: 5)) { results in
    ///     for await result in results {
    ///         await ingest(result)
    ///     }
    /// }
    /// ```
    public init(
        configuration: Configuration = .default,
        iOS17AsyncResults: @escaping @Sendable (AsyncStream<PhotoPickerResult>) async -> Void
    ) {
        let sink = AsyncResultsSink()
        let stream = sink.stream
        Task { await iOS17AsyncResults(stream) }
        self.init(asyncSink: sink, configuration: configuration)
    }
}

#endif
