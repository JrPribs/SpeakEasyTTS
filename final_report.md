# macOS Menu Bar Text-to-Speech App: Research, Design, and Implementation

**Author:** Manus AI
**Date:** February 3, 2026

## 1. Introduction

This document outlines the research, design, and implementation of a native macOS menu bar application for text-to-speech (TTS). The project aims to create a simple, fast, and user-friendly TTS solution that addresses the gaps in the current market. The app provides core functionality such as reading selected text via a global hotkey, a floating window for manual input, and seamless integration with macOS's built-in TTS capabilities, with an optional integration for higher-quality online voices.

This report details the competitive landscape, the proposed application architecture, the complete Swift/SwiftUI source code, and recommendations for a potential iOS companion app.

## 2. Competitive Analysis

A thorough analysis of the existing macOS TTS market was conducted to identify key features, pricing models, and user pain points. The research included market leaders like Speechify, accessibility-focused apps like Voice Dream Reader, and open-source projects.

### 2.1. Market Landscape

The current market is dominated by powerful but often complex and subscription-based applications. While these apps offer a rich feature set, they can be overwhelming for users who require a simple, fast tool for basic TTS tasks.

| Application | Key Strengths | Key Weaknesses | Pricing Model |
| :--- | :--- | :--- | :--- |
| **Speechify** | 200+ voices, cross-platform sync, AI features | Monthly word limits, unreliable premium voices, expensive | Freemium with subscription |
| **Voice Dream Reader** | Apple Design Award winner, offline support, high accessibility | Primarily focused on long-form reading, can be complex | Paid app with in-app purchases |
| **NaturalReader** | MP3 conversion, OCR, cross-platform | Similar voice quality issues to Speechify | Freemium with subscription |
| **macOS Built-in** | Free, offline, high-quality enhanced voices | Limited UI, no floating window, no pause/resume from menu bar | Free (included with macOS) |

### 2.2. Gap Analysis and Opportunity

The analysis revealed a significant market opportunity for a lightweight, free, and user-friendly menu bar app that leverages the power of macOS's native TTS engine. Key user frustrations with existing solutions include:

*   **Subscription Fatigue:** Many users are unwilling to pay recurring fees for high-quality voices.
*   **Feature Bloat:** Power-user features often complicate the experience for casual users.
*   **Lack of a Simple Hotkey Solution:** A fast and reliable way to read selected text is a frequently requested feature that is not always well-implemented.

Our proposed application, **SpeakEasy TTS**, is designed to fill this gap by providing a focused and efficient user experience without the cost and complexity of existing solutions.

## 3. Application Design and Architecture

The architecture of SpeakEasy TTS is designed for simplicity, performance, and extensibility. It is built entirely in Swift and SwiftUI, leveraging modern Apple technologies.

### 3.1. Architecture Diagram

The following diagram illustrates the high-level architecture of the application, detailing the separation of concerns between the UI, core logic, speech engine, and data layers.

![Application Architecture Diagram](/home/ubuntu/tts_research/architecture.png)

### 3.2. Core Components

*   **Application Core:** A central `AppState` class, using Swift's `@Observable` macro, acts as the single source of truth. The `AppDelegate` manages the app's lifecycle and the `HotkeyManager` handles global keyboard shortcuts using the Carbon framework for reliability.
*   **Speech Engine Layer:** A protocol-based `SpeechService` allows for interchangeable TTS engines. The initial implementation includes a `NativeSpeechService` (using `AVSpeechSynthesizer`) and an optional `EdgeTTSService` for high-quality online voices.
*   **SwiftUI Views:** The entire user interface, from the menu bar dropdown to the floating input window and settings, is built with SwiftUI for a modern and maintainable codebase.
*   **Data & Settings:** User preferences are persisted using a `SettingsStore` that serializes a `SpeechSettings` model to `UserDefaults`.

## 4. macOS Menu Bar App Implementation

A complete, working version of the SpeakEasy TTS application has been developed. The source code is organized into a Swift Package for easy building and dependency management.

### 4.1. Project Structure

The project is structured logically to separate concerns:

*   `Sources/App`: Main application entry point and delegate.
*   `Sources/Core`: Central state management, speech services, and hotkey logic.
*   `Sources/Models`: Data models like `Voice`, `SpeechSettings`, and `PlaybackState`.
*   `Sources/Services`: Helper services for settings persistence, voice discovery, and clipboard management.
*   `Sources/Views`: All SwiftUI views for the user interface.
*   `Sources/Resources`: Application assets, including the `Info.plist`.

### 4.2. Source Code

The complete and buildable Swift project is provided in the `SpeakEasyTTS.zip` archive. The code is extensively commented to explain key components and design decisions. A `build.sh` script is included to demonstrate how to compile the project and create a standard macOS `.app` bundle.

## 5. iOS Companion App Recommendations

An iOS companion app would significantly enhance the value of SpeakEasy TTS by providing a seamless cross-device experience. The recommended approach is to build a multi-platform application using SwiftUI.

### 5.1. Recommended Approach: SwiftUI Multiplatform

Leveraging SwiftUI's multi-platform capabilities is the most efficient strategy. This approach allows for a single codebase for the majority of the application's logic, including the speech engine, state management, and data models. Platform-specific UI and features can be implemented using conditional compilation and target-specific files.

### 5.2. Core iOS Features

An iOS version should include the following key features:

*   **Share Extension:** Allow users to send text from any app to SpeakEasy for reading.
*   **iCloud Sync:** Synchronize voice and speed preferences between macOS and iOS devices.
*   **Background Audio:** Continue playback even when the app is not in the foreground.
*   **Siri Shortcuts:** Enable hands-free operation with commands like "Hey Siri, read my last article."
*   **Widget Support:** Provide a home screen widget for quick access to recent texts or clipboard reading.

### 5.3. Technical Implementation

The foundation of the iOS app would be Apple's `AVSpeechSynthesizer`, the same API used in the macOS version, ensuring consistent performance and voice availability. The shared codebase would be organized into a Swift Package to be consumed by both the macOS and iOS app targets.

## 6. Conclusion

This project successfully demonstrates the feasibility of creating a high-quality, user-friendly TTS application for macOS that is both free and powerful. By focusing on a core set of essential features and leveraging native system frameworks, SpeakEasy TTS provides a compelling alternative to the existing subscription-based and often overly complex applications on the market. The provided architecture and source code serve as a solid foundation for a production-ready application and future expansion to iOS.

## 7. References

[1] Apple Inc. "AVSpeechSynthesizer | Apple Developer Documentation". developer.apple.com.
[2] GitHub. "SchneeHertz/node-edge-tts". github.com.
[3] Apple Inc. "Food Truck: Building a SwiftUI multiplatform app". developer.apple.com.
[4] GitHub. "minac/speakeasy-mac: Native macOS menu bar app for text-to-speech using AVSpeechSynthesizer". github.com.
