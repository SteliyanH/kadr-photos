import Testing
import Foundation
#if canImport(PhotosUI)
import PhotosUI
#endif
@testable import KadrPhotos

/// Tests for v0.6 Tier 2 — `PhotoPicker(...iOS17AsyncResults:)` async-stream
/// delivery path. Exercises `AsyncResultsSink` and the `deliver(_:via:)`
/// dispatch helper directly — the SwiftUI body itself needs a real picker
/// presentation and is covered by integration testing in a host app.
struct PhotoPickerAsyncResultsTests {

    #if canImport(PhotosUI)

    // MARK: - AsyncResultsSink

    @Test func sinkStreamYieldsDeliveredResultsThenFinishes() async {
        let sink = AsyncResultsSink()
        let payload = [
            PhotoPickerResult(assetIdentifier: "a"),
            PhotoPickerResult(assetIdentifier: "b"),
            PhotoPickerResult(assetIdentifier: "c"),
        ]

        let collected = Task<[PhotoPickerResult], Never> {
            var out: [PhotoPickerResult] = []
            for await result in sink.stream {
                out.append(result)
            }
            return out
        }

        sink.deliver(payload)
        let received = await collected.value
        #expect(received == payload)
    }

    @Test func sinkEmptyDeliveryFinishesStreamImmediately() async {
        let sink = AsyncResultsSink()

        let collected = Task<Int, Never> {
            var count = 0
            for await _ in sink.stream { count += 1 }
            return count
        }

        sink.deliver([])
        let count = await collected.value
        #expect(count == 0)
    }

    // MARK: - deliver(_:via:)

    @Test @MainActor func deliverViaAsyncStreamForwardsToSink() async {
        let sink = AsyncResultsSink()
        let payload = [PhotoPickerResult(assetIdentifier: "x")]

        let collected = Task<[PhotoPickerResult], Never> {
            var out: [PhotoPickerResult] = []
            for await r in sink.stream { out.append(r) }
            return out
        }

        PhotoPicker.deliver(payload, via: .asyncStream(sink))
        let received = await collected.value
        #expect(received == payload)
    }

    // MARK: - Public init wiring

    @Test func sinkContinuationSurvivesAcrossActorHop() async {
        // Mirrors the runtime path: the coordinator hops to @MainActor before
        // invoking `deliver` from a non-isolated PHPicker delegate callback.
        // The stream consumer (started before delivery) must observe the items.
        let sink = AsyncResultsSink()
        let payload = [PhotoPickerResult(assetIdentifier: "z")]

        let collector = Task<[PhotoPickerResult], Never> {
            var out: [PhotoPickerResult] = []
            for await r in sink.stream { out.append(r) }
            return out
        }

        await MainActor.run {
            PhotoPicker.deliver(payload, via: .asyncStream(sink))
        }

        let received = await collector.value
        #expect(received == payload)
    }

    #endif
}
