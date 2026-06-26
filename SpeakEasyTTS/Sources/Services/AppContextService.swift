// AppContextService.swift
// Tracks the user's active external app for selection and insertion flows.

import AppKit
import Foundation

final class AppContextService {
    private let frontmostApplication: () -> NSRunningApplication?
    private let currentBundleIdentifier: () -> String?
    private let now: () -> Date
    private var lastExternalApp: NSRunningApplication?
    private var lastExternalAppContext: AppContext?

    init(
        frontmostApplication: @escaping () -> NSRunningApplication? = { NSWorkspace.shared.frontmostApplication },
        currentBundleIdentifier: @escaping () -> String? = { Bundle.main.bundleIdentifier },
        now: @escaping () -> Date = { Date() }
    ) {
        self.frontmostApplication = frontmostApplication
        self.currentBundleIdentifier = currentBundleIdentifier
        self.now = now
    }

    func currentFrontmostApplication() -> NSRunningApplication? {
        frontmostApplication()
    }

    func isCurrentApplication(_ application: NSRunningApplication) -> Bool {
        application.bundleIdentifier == currentBundleIdentifier()
    }

    func trackFrontmostApp() {
        _ = currentExternalApplication()
    }

    func currentExternalApplication() -> NSRunningApplication? {
        guard let frontmost = frontmostApplication(),
              !isCurrentApplication(frontmost) else {
            return nil
        }

        rememberExternalApplication(frontmost)
        return frontmost
    }

    func lastExternalApplication() -> NSRunningApplication? {
        guard let app = lastExternalApp,
              !app.isTerminated else {
            return nil
        }

        return app
    }

    func targetApplicationForUserInteraction() -> NSRunningApplication? {
        currentExternalApplication() ?? lastExternalApplication()
    }

    func lastExternalApplicationContext() -> AppContext? {
        guard lastExternalApplication() != nil else {
            return nil
        }

        return lastExternalAppContext
    }

    func context(for application: NSRunningApplication) -> AppContext {
        Self.makeContext(
            bundleIdentifier: application.bundleIdentifier,
            localizedName: application.localizedName,
            processIdentifier: application.processIdentifier,
            capturedAt: now()
        )
    }

    func targetAppContextForUserInteraction() -> AppContext? {
        guard let target = targetApplicationForUserInteraction() else {
            return nil
        }

        if target == lastExternalApplication() {
            return lastExternalApplicationContext()
        }

        return context(for: target)
    }

    static func makeContext(
        bundleIdentifier: String?,
        localizedName: String?,
        processIdentifier: Int32?,
        capturedAt: Date
    ) -> AppContext {
        AppContext(
            bundleIdentifier: bundleIdentifier,
            appName: localizedName ?? bundleIdentifier ?? "Unknown App",
            processIdentifier: processIdentifier,
            capturedAt: capturedAt
        )
    }

    private func rememberExternalApplication(_ application: NSRunningApplication) {
        lastExternalApp = application
        lastExternalAppContext = context(for: application)
    }
}
