import Foundation
@testable import SurrealDB
import Testing

// MARK: - Cache Policy Tests

@Suite("Cache Policy Tests")
struct CachePolicyTests {
    @Test("Default policy values")
    func defaultPolicyValues() {
        let policy = CachePolicy.default

        #expect(policy.defaultTTL == 300)
        #expect(policy.maxEntries == 1000)
        #expect(policy.invalidateOnLiveQuery == true)
    }

    @Test("Aggressive policy values")
    func aggressivePolicyValues() {
        let policy = CachePolicy.aggressive

        #expect(policy.defaultTTL == 1800)
        #expect(policy.maxEntries == 5000)
    }

    @Test("Short-lived policy values")
    func shortLivedPolicyValues() {
        let policy = CachePolicy.shortLived

        #expect(policy.defaultTTL == 30)
        #expect(policy.maxEntries == 100)
    }

    @Test("Custom policy")
    func customPolicy() {
        let policy = CachePolicy(
            defaultTTL: 60,
            maxEntries: 200,
            evictionStrategy: .lru,
            invalidateOnLiveQuery: false
        )

        #expect(policy.defaultTTL == 60)
        #expect(policy.maxEntries == 200)
        #expect(policy.invalidateOnLiveQuery == false)
    }

    @Test("Policy with nil TTL and nil maxEntries")
    func policyWithNilValues() {
        let policy = CachePolicy(
            defaultTTL: nil,
            maxEntries: nil
        )

        #expect(policy.defaultTTL == nil)
        #expect(policy.maxEntries == nil)
    }
}

// MARK: - CacheStats Tests

@Suite("Cache Stats Tests")
struct CacheStatsTests {
    @Test("CacheStats stores all properties correctly")
    func cacheStatsProperties() {
        let now = Date()
        let earlier = now.addingTimeInterval(-60)

        let stats = CacheStats(
            totalEntries: 10,
            expiredEntries: 2,
            tables: Set(["users", "posts"]),
            oldestEntry: earlier,
            newestEntry: now
        )

        #expect(stats.totalEntries == 10)
        #expect(stats.expiredEntries == 2)
        #expect(stats.tables.count == 2)
        #expect(stats.tables.contains("users"))
        #expect(stats.tables.contains("posts"))
        #expect(stats.oldestEntry == earlier)
        #expect(stats.newestEntry == now)
    }

    @Test("CacheStats with nil dates when empty")
    func cacheStatsEmptyDates() {
        let stats = CacheStats(
            totalEntries: 0,
            expiredEntries: 0,
            tables: [],
            oldestEntry: nil,
            newestEntry: nil
        )

        #expect(stats.totalEntries == 0)
        #expect(stats.oldestEntry == nil)
        #expect(stats.newestEntry == nil)
    }
}
