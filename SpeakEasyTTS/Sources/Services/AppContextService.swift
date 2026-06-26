// AppContextService.swift
// Tracks the user's active external app for selection and insertion flows.

import AppKit
import Foundation

enum TargetAppResolution {
    case focused(NSRunningApplication, AppContext)
    case recoverable(NSRunningApplication, AppContext)

    var application: NSRunningApplication {
        switch self {
        case .focused(let application, _), .recoverable(let application, _):
            return application
        }
    }

    var context: AppContext {
        switch self {
        case .focused(_, let context), .recoverable(_, let context):
            return context
        }
    }

    var isRecoverableFallback: Bool {
        if case .recoverable = self {
            return true
        }
        return false
    }
}

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

    func resolveTargetApplicationForTextInsertion(
        intendedTarget: AppContext? = nil
    ) -> TargetAppResolution? {
        guard let frontmost = frontmostApplication() else {
            return recoverableLastExternalApplication(matching: intendedTarget)
        }

        if !isCurrentApplication(frontmost) {
            let context = context(for: frontmost)
            guard targetContext(context, matches: intendedTarget) else {
                return nil
            }

            rememberExternalApplication(frontmost)
            return .focused(frontmost, context)
        }

        return recoverableLastExternalApplication(matching: intendedTarget)
    }

    private func recoverableLastExternalApplication(
        matching intendedTarget: AppContext?
    ) -> TargetAppResolution? {
        guard let last = lastExternalApplication(),
              let context = lastExternalApplicationContext(),
              targetContext(context, matches: intendedTarget) else {
            return nil
        }

        return .recoverable(last, context)
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

    private func targetContext(
        _ context: AppContext,
        matches intendedTarget: AppContext?
    ) -> Bool {
        guard let intendedTarget else { return true }

        if let intendedPID = intendedTarget.processIdentifier,
           let contextPID = context.processIdentifier {
            return intendedPID == contextPID
        }

        if let intendedBundleID = intendedTarget.bundleIdentifier,
           let contextBundleID = context.bundleIdentifier {
            return intendedBundleID == contextBundleID
        }

        return false
    }
}
