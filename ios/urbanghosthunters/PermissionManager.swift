//
//  PermissionsManager.swift
//  urbanghosthunters
//

import Foundation
import CoreLocation
import AVFoundation
import UserNotifications

@Observable
@MainActor
final class PermissionsManager {
    static let shared = PermissionsManager()

    var locationStatus: CLAuthorizationStatus = .notDetermined
    var cameraStatus: AVAuthorizationStatus = .notDetermined
    var micStatus: AVAuthorizationStatus = .notDetermined
    var notificationStatus: UNAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()

    private init() {
        locationStatus = locationManager.authorizationStatus
        Task { await refreshStatuses() }
    }

    // MARK: - Request all at once
    func requestAll() async {
        requestLocation()
        await requestCamera()
        await requestMic()
        await requestNotifications()
    }

    // MARK: - Location
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationStatus = locationManager.authorizationStatus
    }

    // MARK: - Camera
    func requestCamera() async {
        let status = await AVCaptureDevice.requestAccess(for: .video)
        cameraStatus = status ? .authorized : .denied
    }

    // MARK: - Microphone
    func requestMic() async {
        let status = await AVCaptureDevice.requestAccess(for: .audio)
        micStatus = status ? .authorized : .denied
    }

    // MARK: - Notifications
    func requestNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            notificationStatus = granted ? .authorized : .denied
        } catch {
            notificationStatus = .denied
        }
    }

    // MARK: - Refresh current statuses
    func refreshStatuses() async {
        locationStatus = locationManager.authorizationStatus
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    // MARK: - Convenience
    var locationGranted: Bool { locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways }
    var cameraGranted: Bool { cameraStatus == .authorized }
    var micGranted: Bool { micStatus == .authorized }
    var notificationsGranted: Bool { notificationStatus == .authorized }
}