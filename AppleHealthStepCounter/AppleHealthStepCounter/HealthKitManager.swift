import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?

    @Published var stepCount: Int = 0
    @Published var isAuthorized = false
    @Published var isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
    @Published var errorMessage: String?

    private let stepType = HKQuantityType(.stepCount)

    func requestAuthorization() async {
        guard isHealthKitAvailable else { return }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            isAuthorized = true
            await fetchTodaySteps()
            startObserving()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchTodaySteps() async {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now)

        do {
            let stats: HKStatistics? = try await withCheckedThrowingContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: stepType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, result, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: result)
                    }
                }
                healthStore.execute(query)
            }
            stepCount = Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startObserving() {
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: nil
        )
        let query = HKObserverQuery(sampleType: stepType, predicate: predicate) { [weak self] _, completionHandler, error in
            guard error == nil else { completionHandler(); return }
            Task { @MainActor [weak self] in
                await self?.fetchTodaySteps()
            }
            completionHandler()
        }
        observerQuery = query
        healthStore.execute(query)
        // Deliver updates immediately when new step data arrives
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }
    }
}
