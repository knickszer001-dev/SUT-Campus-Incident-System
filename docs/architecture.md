# System Architecture & Design

This document provides a detailed breakdown of the SUT Campus Incident System's technical architecture, component design patterns, and cross-platform adaptations.

---

## 1. Clean Architecture & Feature-First Strategy

The client application enforces a strict separation of concerns, decoupling user interfaces from database clients and core business rules.

```
       ┌────────────────────────────────────────────────────────┐
       │                   PRESENTATION LAYER                   │
       │  (UI Widgets, Responsive Panels, Screens, Controllers)  │
       └───────────────────────────┬────────────────────────────┘
                                   │ Watches
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │                      DOMAIN LAYER                      │
       │       (State Transition Rules, Validation Logic)        │
       └───────────────────────────┬────────────────────────────┘
                                   │ Invokes
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │                       DATA LAYER                       │
       │  (Repositories, Firebase Auth/Firestore, FCM Services) │
       └────────────────────────────────────────────────────────┘
```

### Presentation Layer
*   **Decoupled Rebuilds**: Widgets listen to Riverpod `StreamProviders` (`currentUserProvider`, `authStateProvider`) directly. UI components do not store local copies of remote data.
*   **Adaptive Interfaces**: Employs `LayoutBuilder` widgets to dynamically rearrange views. Small screens (< 700px) compile to linear bottom-tab views, whereas desktop or web clients display side-by-side split panels (e.g., active maps next to suggestion tables).

### Domain Layer
*   **Business Integrity Gates**: Housed in scripts like `responder_logic.dart`. It verifies status transitions before updating the database, preventing invalid workflow moves (e.g., skipping from `NEW` directly to `ARRIVED`).

### Data Layer
*   **Repository Pattern**: Data clients (`AuthRepository`, `IncidentRepository`, `ChatRepository`, `DirectChatRepository`) handle low-level Firebase API connections, map data models to/from JSON, and handle background service isolates.

---

## 2. Cross-Platform Map Adapter (`AdaptiveMapWidget`)

To support maps across mobile, web, and desktop without maintaining separate widget trees or incurring expensive map API fees, the project implements a custom adapter:

```
                          ┌──────────────────────┐
                          │  AdaptiveMapWidget   │
                          └──────────┬───────────┘
                                     │
                 ┌───────────────────┴───────────────────┐
                 ▼                                       ▼
       [Google Maps Flutter]                      [Flutter Map (OSM)]
       - Native Mobile (Android/iOS)              - Desktop (Windows/Web)
       - Google Maps Vector engine                - Leaflet OpenStreetMap tiles
```

*   **Mobile Execution**: Integrates native Google Maps via `google_maps_flutter`, loading SUT custom map styles.
*   **Web & Desktop Execution**: Bypasses heavy JS dependencies by rendering Leaflet tiles through `flutter_map` connected to OpenStreetMap. Both wrappers present a unified API (`animateToLatLng`, custom markers) to the main controller.

---

## 3. Double-Notification Suppression Engine

Audible alert loops can be intrusive if a user is actively looking at a chat room. The system implements a dynamic state watcher to suppress redundant notifications:

```
[Incoming FCM Chat Payload] 
            │
            ▼
[Query WebNotificationWatcher] ──► Checks activeIncidentChatId / activeDmChatId
            │
            ├─► Matches open room ID ──► Suppress audio alert & visual HUD popups
            │
            └─► ID mismatch or closed ─► Trigger audible alerts & play alert.mp3
```

1.  **State Watching**: The global `WebNotificationWatcher` tracks the current screen and active chat UIDs.
2.  **Comparison Gate**: When a new message document snapshot is received, the listener compares its `incidentId` or `chatId` against the active watcher parameters.
3.  **Suppression**: If they match, the audio chime is muted, ensuring a quiet, real-time messaging experience.
