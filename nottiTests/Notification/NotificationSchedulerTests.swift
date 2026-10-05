//
//  NotificationSchedulerTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing
import UserNotifications

struct NotificationSchedulerTests {
    private let id = UUID()

    @Test(arguments: NotificationInterval.allCases)
    func scheduleAddsRepeatingTimeIntervalRequest(interval: NotificationInterval) async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)

        try await scheduler.schedule(id: id, message: "水を飲む", interval: interval, startDate: .now)

        let pending = center.pending
        #expect(pending.count == 1)
        let request = try #require(pending[id.uuidString])
        #expect(request.content.body == "水を飲む")
        #expect(request.content.sound == .default)
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.timeInterval == TimeInterval(interval.hours * 3600))
    }

    @Test
    func intervalSeconds() {
        #expect(NotificationInterval.oneHour.timeInterval == 3600)
        #expect(NotificationInterval.twentyFourHours.timeInterval == 86_400)
    }

    @Test
    func scheduleReplacesRequestWithSameIdentifier() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)

        try await scheduler.schedule(id: id, message: "古い文言", interval: .oneHour, startDate: .now)
        try await scheduler.schedule(id: id, message: "新しい文言", interval: .twentyFourHours, startDate: .now)

        let pending = center.pending
        #expect(pending.count == 1)
        let request = try #require(pending[id.uuidString])
        #expect(request.content.body == "新しい文言")
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == 86_400)
    }

    @Test
    func scheduleKeepsOtherNotifications() async throws {
        let otherID = UUID()
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)

        try await scheduler.schedule(id: otherID, message: "別の通知", interval: .oneHour, startDate: .now)
        try await scheduler.schedule(id: id, message: "水を飲む", interval: .oneHour, startDate: .now)

        let identifiers = Set(center.pending.keys)
        #expect(identifiers == [otherID.uuidString, id.uuidString])
    }

    @Test
    func removeDeletesRequestAndDerivedRequests() async throws {
        let otherID = UUID()
        let center = FakeNotificationCenter(pending: [
            Self.request(identifier: id.uuidString),
            Self.request(identifier: "\(id.uuidString)-9"),
            Self.request(identifier: "\(id.uuidString)-21"),
            Self.request(identifier: otherID.uuidString),
            Self.request(identifier: "\(otherID.uuidString)-9")
        ])
        let scheduler = NotificationScheduler.fake(center)

        await scheduler.remove(id: id)

        let identifiers = Set(center.pending.keys)
        #expect(identifiers == [otherID.uuidString, "\(otherID.uuidString)-9"])
    }

    @Test
    func removeWithoutPendingRequestsDoesNothingHarmful() async {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler.fake(center)

        await scheduler.remove(id: id)

        #expect(center.pending.isEmpty)
        #expect(center.removedIdentifiers == [[id.uuidString]])
    }

    @Test
    func identifierIsUUIDString() {
        #expect(NotificationScheduler.identifier(for: id) == id.uuidString)
    }

    private static func request(identifier: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.body = identifier
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }
}
