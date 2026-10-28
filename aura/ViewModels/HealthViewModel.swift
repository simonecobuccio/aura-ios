import SwiftUI
import HealthKit
import Combine

@MainActor
class HealthViewModel: ObservableObject {

    @Published var steps:        Int    = 0
    @Published var sleepHours:   Double = 0
    @Published var heartRate:    Double = 0
    @Published var isAuthorized: Bool   = false

    private let healthStore = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var t = Set<HKObjectType>()
        if let s  = HKObjectType.quantityType(forIdentifier: .stepCount)     { t.insert(s) }
        if let sl = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { t.insert(sl) }
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate)     { t.insert(hr) }
        return t
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, _ in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success { self.fetchAll() }
            }
        }
    }

    func fetchAll() {
        fetchSteps()
        fetchSleep()
        fetchHeartRate()
    }

    private func fetchSteps() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let pred  = HKQuery.predicateForSamples(withStart: start, end: Date(),
                                                 options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: pred,
                                      options: .cumulativeSum) { _, result, _ in
            DispatchQueue.main.async {
                self.steps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            }
        }
        healthStore.execute(query)
    }

    private func fetchSleep() {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        let pred  = HKQuery.predicateForSamples(withStart: yesterday, end: Date(),
                                                 options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type,
                                   predicate: pred,
                                   limit: HKObjectQueryNoLimit,
                                   sortDescriptors: nil) { _, samples, _ in
            let total = (samples as? [HKCategorySample])?.reduce(0.0) { acc, s in
                let asleep = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                guard asleep.contains(s.value) else { return acc }
                return acc + s.endDate.timeIntervalSince(s.startDate)
            } ?? 0
            DispatchQueue.main.async { self.sleepHours = total / 3600 }
        }
        healthStore.execute(query)
    }

    private func fetchHeartRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let sort  = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type,
                                   predicate: nil,
                                   limit: 1,
                                   sortDescriptors: [sort]) { _, samples, _ in
            let bpm = (samples?.first as? HKQuantitySample)?
                .quantity.doubleValue(for: HKUnit(from: "count/min")) ?? 0
            DispatchQueue.main.async { self.heartRate = bpm }
        }
        healthStore.execute(query)
    }

    /// Sleep score: optimal window is 7–9h. Tapering on both sides
    /// (too little AND too much sleep hurt wellbeing).
    var sleepScore: Double {
        switch sleepHours {
        case 7.5...8.5: return 1.0    // perfect
        case 7..<7.5:   return 0.88
        case 8.5..<9.0: return 0.90
        case 6.5..<7.0: return 0.72
        case 9.0..<9.5: return 0.75
        case 6.0..<6.5: return 0.55
        case 9.5..<10:  return 0.55   // oversleep penalty
        case 5.0..<6.0: return 0.35
        case 10...:     return 0.35
        case 4.0..<5.0: return 0.18
        default:        return 0.08   // < 4h
        }
    }

    /// Steps score: logarithmic curve — first 5k steps matter most,
    /// diminishing returns after that. 10k = 0.88, 15k = ~1.0.
    var stepsScore: Double {
        guard steps > 0 else { return 0 }
        // log curve: score = log(1 + steps/2000) / log(1 + 15000/2000)
        let raw = log(1.0 + Double(steps) / 2000.0) / log(1.0 + 15000.0 / 2000.0)
        return min(raw, 1.0)
    }
}
