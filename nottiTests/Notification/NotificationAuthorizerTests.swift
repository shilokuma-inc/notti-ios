//
//  NotificationAuthorizerTests.swift
//  nottiTests
//

@testable import notti
import Testing
import UserNotifications

struct NotificationAuthorizerTests {
    @Test(arguments: [
        (UNAuthorizationStatus.notDetermined, NotificationAuthorization.notDetermined),
        (.denied, .denied),
        (.authorized, .allowed),
        (.provisional, .allowed),
        (.ephemeral, .allowed)
    ])
    func authorizationMapsStatus(status: UNAuthorizationStatus, expected: NotificationAuthorization) async {
        let authorizer = NotificationAuthorizer(center: FakeNotificationCenter(status: status))
        #expect(await authorizer.authorization() == expected)
    }

    @Test(arguments: [(true, NotificationAuthorization.allowed), (false, .denied)])
    func requestsWhenNotDetermined(grants: Bool, expected: NotificationAuthorization) async {
        let center = FakeNotificationCenter(status: .notDetermined, grantsAuthorization: grants)
        let authorizer = NotificationAuthorizer(center: center)

        let result = await authorizer.requestIfNeeded()

        #expect(result == expected)
        #expect(center.requestedOptions == [[.alert, .sound, .badge]])
    }

    @Test(arguments: [UNAuthorizationStatus.denied, .authorized])
    func doesNotRequestWhenAlreadyDetermined(status: UNAuthorizationStatus) async {
        let center = FakeNotificationCenter(status: status)
        let authorizer = NotificationAuthorizer(center: center)

        let result = await authorizer.requestIfNeeded()

        #expect(result == NotificationAuthorization(status))
        #expect(center.requestedOptions.isEmpty)
    }
}
