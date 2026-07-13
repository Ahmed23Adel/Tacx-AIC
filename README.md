# AIC — Art Institute of Chicago Browser

A SwiftUI app that browses works by a chosen artist (**Rembrandt van Rijn**) from the
[Art Institute of Chicago API](https://api.artic.edu/docs/): a paginated thumbnail feed and a
rich detail screen, with a **5‑minute cache**, **offline request parking**, and a suite of
**285 unit + integration tests** covering ~100% of the business logic.

## Table of Contents

- [Design](#-design)
- [Device Testing](#device-testing)
- [Overview](#1-overview)
- [Requirements checklist](#2-requirements-checklist)
- [Build & run](#3-build--run)
- [Architecture](#4-architecture)
- [Component Diagram](#5-component-diagram)
- [Data flow](#6-data-flow--how-a-page-request-is-decided)
- [Caching behaviour](#7-caching-behaviour--the-four-modes)
- [Separation of concerns](#8-separation-of-concerns)
- [Local storage layer](#9-local-storage-layer)
- [UI & Accessibility, Light/Dark/High Contrast](#10-ui--accessibility-lightdarkhigh-contrast)
- [Data exploration](#11-data-exploration)
- [Nullability Strategy](#12-nullability-strategy--building-for-a-year-from-now)
- [Testing](#13-testing)
- [Debug logging & tracing](#14-debug-logging--tracing)
- [Performance profiling](#15-performance-profiling-instruments--time-profiler)
- [Memory graph debugging](#16-memory-graph-debugging-xcode)
- [Coding style](#17-coding-style)
- [Dependencies](#18-dependencies)
- [Known limitations](#19-known-limitations--possible-next-steps)
- [Assumptions](#assumptions)
---

## 🎨 Design

The app's visual design (layout, spacing, colour usage, the detail screen composition) was
prototyped with **Claude design** before implementation — deliberately kept simple and modern
rather than over‑styled, then translated to SwiftUI using system colours and text styles.

<table align="center">
  <tr>
    <td align="center">
      <img src="https://github.com/user-attachments/assets/e694eba7-ba5e-415b-8392-f262271b1e76"
           alt="Search Screen"
           width="280" />
      <br />
      <b>Search Screen</b>
    </td>
    <td align="center">
      <img src="https://github.com/user-attachments/assets/a3d7c23c-0fa3-4032-83e6-351d00772b2d"
           alt="Detail Screen"
           width="280" />
      <br />
      <b>Detail Screen</b>
    </td>
  </tr>
</table>
---

## Device Testing

The application was tested on a physical **iPhone 13** to verify layout, navigation, accessibility, caching behaviour, and UI consistency across different appearance modes.

### Light Mode

<table>
<tr>
<td align="center">
<img src="https://github.com/user-attachments/assets/12ee8d52-bae7-4a7d-ab01-d42b79970914" width="280" />
<br><b>Search View</b>
</td>
<td align="center">
<img src="https://github.com/user-attachments/assets/33687424-4d80-405d-9247-40cc98ce854c" width="280" />
<br><b>Detail View</b>
</td>
</tr>
</table>

### Dark Mode

<table>
<tr>
<td align="center">
<img src="https://github.com/user-attachments/assets/1243fd18-6abf-4d19-ab40-96493be6b330" width="280" />
<br><b>Search View</b>
</td>
<td align="center">
<img src="https://github.com/user-attachments/assets/9a8ea42e-6f30-47d5-ac4e-6c843167437a" width="280" />
<br><b>Detail View</b>
</td>
</tr>
</table>

### Expanded Accessibility Contrast

<table>
<tr>
<td align="center">
<img src="https://github.com/user-attachments/assets/2b35d4f2-cbcf-4811-9ec3-e33c806abfd0" width="280" />
<br><b>Search View</b>
</td>
<td align="center">
<img src="https://github.com/user-attachments/assets/7b3b9900-13cf-4f1c-aa2e-bd78d0e9b796" width="280" />
<br><b>Detail View</b>
</td>
</tr>
</table>

### Description States

The detail screen adapts to the available artwork description.

<table>
<tr>
<td align="center">
<img src="https://github.com/user-attachments/assets/adf79e07-3019-4279-a658-66754346ab2f" width="280" />
<br><b>Read More Available</b>
</td>
<td align="center">
<img src="https://github.com/user-attachments/assets/af49be82-aa87-4b2e-b38b-52a707284038" width="280" />
<br><b>Expanded Description</b>
</td>
</tr>
</table>

### Offline Experience

When cached data is available, artworks remain accessible while offline for 5 minuts.

<table>
<tr>
<td align="center">
<img src="https://github.com/user-attachments/assets/edd8b618-0db6-43ae-b500-0a7d330fded0" width="280" />
<br><b>Search View</b>
</td>
<td align="center">
<img src="https://github.com/user-attachments/assets/2026f093-2ee4-4fdb-a26a-53bf251d9b2c" width="280" />
<br><b>Detail View</b>
</td>
</tr>
</table>

### Pull-to-Refresh

The application supports manual refresh on both screens.

<table>
<tr>
<td align="center">
<img src="https://github.com/user-attachments/assets/f88a6350-8af3-47fa-ab23-442d55cba641" width="280" />
<br><b>Search View Refresh</b>
</td>
<td align="center">
<img src="https://github.com/user-attachments/assets/ff742665-a9d8-421b-8021-212491ef0fbe" width="280" />
<br><b>Detail View Refresh</b>
</td>
</tr>
</table>

### Device is offline and no invalid cached data 
The application displays a dedicated error state and automatically retries the request once connectivity is restored.

<p align="center">
  <img src="https://github.com/user-attachments/assets/397b5a7e-90f2-45b7-b26a-4b5c51175a15"
       width="280"
       alt="No Network and No Cache" />
  <br>
  <b>Offline Error State</b>
</p>

### Small-Screen Validation (iPhone SE 3rd Generation)

The application was also tested on an **iPhone SE (3rd generation)** to verify that the layout remains usable on compact devices. Navigation, typography, image presentation, and scrolling behavior were validated in both Light and Dark Mode.

<table>
<tr>
<td align="center">
<img src="https://github.com/user-attachments/assets/f26014a7-81da-4531-945d-897cd0b9d409" width="220" />
<br><b>Search View</b>
</td>
<td align="center">
<img src="https://github.com/user-attachments/assets/97ef5ff5-cfeb-400a-ab16-c8d5cd450bae" width="220" />
<br><b>Detail View</b>
</td>
<td align="center">
<img src="https://github.com/user-attachments/assets/1e170e10-8a4d-483b-b836-0e4f0b855b23" width="220" />
<br><b>Detail View (Scrolled)</b>
</td>
</tr>
</table>

---

## 1. Overview

The app has two screens:

- **Search feed** — a paginated list of the artist's works (thumbnail + title + date), with
  infinite scroll, pull‑to‑refresh, an end‑of‑list marker, and clear offline/error states.
- **Detail** — a large edge‑to‑edge image, title, artist, a date chip, a facts table
  (medium, dimensions, place of origin, credit line), and an expandable HTML description.

Everything the user sees flows through a **caching layer** that decides, per page and per
artwork, whether to serve local data or hit the network — and when there's no connection, it
**parks** the request and completes it automatically once connectivity returns.

**Project at a glance**

| | |
|---|---|
| Language / UI | Swift, SwiftUI (`@Observable`, iOS 17+ Observation) |
| Min iOS | 17.6 |
| Architecture | MVVM + Coordinator, layered (UI → Repository → Networking/LocalStorage) |
| Persistence | SwiftData |
| Networking | Alamofire |
| Images | Kingfisher |
| Tests | 285 unit + integration tests; ~100% of business‑logic files |

---

## 2. Requirements checklist

Every requirement from the assignment, mapped to where it lives:

| Requirement | Status | Where |
|---|---|---|
| Thumbnail overview (image + title), non‑empty | ✅ | `ViewSearchArtworks`, `ArtworkRowView` |
| Detail screen with relevant data + large image | ✅ | `ViewArtworkDetail` |
| Navigation between the two | ✅ | `Coordinator` + `AppCoordinator` |
| Animations / interactions (pull‑to‑refresh) | ✅ | `.refreshable` on both screens |
| Cache API data to local/memory storage | ✅ | `LocalStorage/` (SwiftData) |
| Refresh cached data every 5 minutes | ✅ | `AppConstants.Cache.timeToLive`, `CachedArtworkRepository` |
| On start, don't call API if cache not expired | ✅ | `CachedArtworkRepository.searchArtworks(page:)` |
| Inform the user when a fetch error occurs | ✅ | Error alert (VMs → `LocalizedError` messages) |
| Park the call when offline, run it on reconnect | ✅ | `NetworkMonitor.waitForConnection()` |
| Cover the code with unit tests | ✅ | `AICTests/` (285 tests, ~100% business logic) |

---

## 3. Build & run

1. Open `AIC.xcodeproj` in Xcode.
2. Select any iOS 26.5+ simulator or device.
3. **⌘R** to run. No setup, keys, or config files — all SPM dependencies resolve automatically.

**Tests:** **⌘U**. To see coverage: Scheme → Test → Options → enable *Code Coverage*, then read the
Coverage tab in the Report navigator (⌘9).

---

## 4. Architecture

The app is **MVVM + Coordinator**, organised as strict, one‑directional **layers**. Each layer
depends only on the layer below it, and only through a **protocol** — never a concrete type.

<img width="2600" height="1280" alt="Architecture Diagram-selection" src="https://github.com/user-attachments/assets/a61f6053-437e-4b3b-82e9-5f32d3f3e0f9" />

### The layers

**UI Layer — SwiftUI Views + Coordinator.**
Pure presentation. Views hold no business logic; they render `@Observable` view‑model state and
call view‑model methods. The **Coordinator** owns navigation: it holds a typed `[AppRoute]` path
and is the only object that mutates it — views never push routes themselves, they call
`coordinator.goToArtworkDetail(id:)`. `AppCoordinator` is the `NavigationStack` shell that maps
each route to a screen.

**ViewModels (`@Observable`).**
Each screen has one view model that owns loading/error/offline state, exposes display decisions
as computed properties (`showsOfflineBanner`, `showsWaitingForConnection`, …), and talks **only**
to the cache‑policy repository protocol + the network‑monitor protocol. It never sees Alamofire,
SwiftData, URLs, or endpoints.

**Cache‑Policy Layer — `CachedArtworkRepository`.**
The single data entry point for the UI. It decides *where* data comes from: serve fresh cache,
otherwise download → cache → return. It also implements offline **parking** and the 5‑minute TTL.
It composes the two layers below and exposes only domain models upward.

**Remote — Networking.**
`ArtworkRepository` (stateless: every call is a download) wraps `AlamofireAPIRequester`, which
executes typed `Endpoint`s and maps Alamofire errors to a domain `NetworkError`. No Alamofire type
escapes this layer.

**Local — Persistence (SwiftData).**
`SwiftDataArtworkLocalStore` implements two focused store protocols. It stores cached pages and
details with timestamps and maps SwiftData entities ↔ domain models at its boundary. No SwiftData
type escapes this layer.

### Design patterns used (and why)

| Pattern | Where | Why |
|---|---|---|
| **MVVM** | Every screen | Keeps views declarative and pushes all logic into testable `@Observable` view models. |
| **Coordinator** | `Coordinator` / `AppCoordinator` | Removes navigation from views; makes routing a testable unit (typed path → exact‑route assertions). |
| **Repository** | `ArtworkRepository`, `CachedArtworkRepository` | Hides *where* data comes from behind a domain interface; ViewModels don't know cache vs network exists. |
| **Decorator** | `CachedArtworkRepository` wraps the remote repo | Adds caching/offline behaviour around the same shape of interface, without changing callers. |
| **Dependency Injection** | Everywhere; assembled in `AppDependencies` | Every dependency is an injected protocol → each unit is mockable → ~100% test coverage. |
| **Composition Root** | `AppDependencies` | One place builds the concrete graph; nothing below constructs its own dependencies. |
| **Factory** | `ArtworkCacheContainerFactory` | Encapsulates SwiftData container creation + resilient recovery in one place. |
| **Adapter / Anti‑Corruption** | `AFErrorMapper`, `LocalStoreErrorMapper`, `HTMLText`, DTO→domain mapping | Translates each foreign vocabulary (Alamofire errors, SwiftData errors, HTML, JSON) into the app's own at the boundary. |
| **Strategy (injected)** | `DateProviding`, `NetworkMonitorProtocol`, endpoint `parse` step | Swappable behaviour that also makes time, connectivity, and parsing testable. |
| **Prefetch policy** | `PaginationTracker` | Pure, dependency‑free decision object for "should the next page load now?". |

---

<h2>5. Component Diagram</h2>

<p>
The application follows a <strong>protocol-oriented architecture</strong> where each layer depends on
abstractions rather than concrete implementations.
</p>

<h3>Presentation Layer</h3>

<ul>
  <li><code>ViewSearchArtworks</code> → <code>ViewModelSearchArtworks</code></li>
  <li><code>ViewArtworkDetail</code> → <code>ViewModelArtworkDetail</code></li>
  <li>Views use the <code>Coordinator</code> for navigation.</li>
</ul>

<h3>View Models</h3>

<p>
Both ViewModels depend only on the following protocols:
</p>

<ul>
  <li><code>CachedArtworkRepositoryProtocol</code></li>
  <li><code>NetworkMonitorProtocol</code></li>
</ul>

<p>
<code>ViewModelSearchArtworks</code> also uses <code>PaginationTracker</code> to determine when
additional pages should be loaded.
</p>

<h3>Repository Layer</h3>

<p>
<code>CachedArtworkRepository</code> implements the application's caching strategy and coordinates
access to local and remote data sources.
</p>

<p>It depends on:</p>

<ul>
  <li><code>ArtworkRepositoryProtocol</code></li>
  <li><code>SearchResultsLocalStoreProtocol</code></li>
  <li><code>ArtworkDetailLocalStoreProtocol</code></li>
  <li><code>DateProviding</code></li>
  <li><code>NetworkMonitorProtocol</code></li>
</ul>

<h3>Remote Data Layer</h3>

<p>
<code>ArtworkRepository</code> retrieves data through <code>APIRequester</code>.
The concrete implementation, <code>AlamofireAPIRequester</code>, provides this protocol while
encapsulating all Alamofire-specific logic behind <code>Endpoint</code> and
<code>AFErrorMapper</code>.
</p>

<h3>Local Data Layer</h3>

<p>
<code>SwiftDataArtworkLocalStore</code> provides both
<code>SearchResultsLocalStoreProtocol</code> and
<code>ArtworkDetailLocalStoreProtocol</code>.
Internally it uses <code>ArtworkCacheContainerFactory</code> and
<code>LocalStoreErrorMapper</code>, keeping SwiftData isolated from the rest of the application.
</p>

<h3>Dependency Composition</h3>

<p>
<code>AppDependencies</code> acts as the composition root, creating and wiring concrete
implementations at application launch, including <code>CachedArtworkRepository</code> and
<code>NetworkMonitor</code>.
</p>



## 6. Data flow — how a page request is decided

<img width="370" height="554" alt="Screenshot 2026-07-12 at 4 18 10 PM" src="https://github.com/user-attachments/assets/04e0b275-4116-4286-b76f-72061a28894e" />



**Explanation.** The ViewModel always asks the **repository** — it never decides cache vs network
itself. The repository:

1. reads the local store for that page;
2. if the entry exists **and** is younger than 5 minutes, returns it immediately — **no network is
   touched, so this works fully offline**;
3. otherwise it waits at the connectivity gate (parking if offline), downloads *that page only*,
   saves it with a fresh timestamp, and returns it.

The same flow applies per artwork on the detail screen.

---

## 7. Caching behaviour & the four modes

The cache is keyed **per page** (and per artwork for details); each entry carries its own
`insertedAt` timestamp, so pages expire independently rather than all‑or‑nothing.

| Connectivity | Cache for the requested page | What happens | What the user sees |
|---|---|---|---|
| **Online** | valid (fresh) | served from cache, no network | content instantly |
| **Online** | invalid/missing | download → cache → show | spinner → content |
| **Offline** | valid (fresh) | served from cache, network never consulted | content instantly + passive **"You're offline"** banner |
| **Offline** | invalid/missing | request **parks** at the gate | **"No internet connection"** waiting screen → auto‑resolves and loads the moment connectivity returns |

**Page‑level caching in practice.** Suppose page 1 has gone stale but page 2 is still fresh. On
launch the app asks for page 1, sees it's stale, and refreshes *only page 1* — page 2 keeps its
own timestamp and its own expiry. This matches the requirement "don't call the API if the data
has not yet expired": a stale neighbour never invalidates a valid page. The one place the whole
cache is cleared is the **user‑initiated pull‑to‑refresh**, which wipes everything and reloads
page 1 fresh.

**`totalPages`** is stored once per cache lifetime (learned on the first download after each wipe),
so the list knows when it has reached the end even while browsing from cache.

---

## 8. Separation of concerns

This was the guiding principle of the whole project. Each type has exactly one reason to change,
and foreign concepts are translated at every boundary so they never leak upward:

- **Views** know layout, nothing else. **ViewModels** know presentation state, not *how* data is
  fetched. The **repository** knows caching policy, not *how* to talk to a server or a database.
  The **networking** and **storage** layers know their frameworks, and translate everything into
  the app's own domain vocabulary before it crosses their boundary.
- **Domain vs. framework types are kept apart.** `Artwork`/`ArtworkDetail` are pure value types.
  SwiftData `@Model` classes and API response DTOs never escape their layers — mapping functions
  (`toDomain()`, response wrappers) convert at the edge. Alamofire's `AFError` becomes
  `NetworkError`; SwiftData failures become `LocalStoreError`; raw HTML becomes an
  `AttributedString` via `HTMLText`.
- **Policy is separated from mechanism.** The local store records *when* something was cached but
  takes no position on staleness; the 5‑minute TTL rule lives entirely in the cache‑policy layer.
- **Pure logic is extracted from side effects.** `PaginationTracker` (when to prefetch),
  `AFErrorMapper`/`LocalStoreErrorMapper` (error translation), and `HTMLText.bodyFont` are pure
  functions/values with no dependencies — trivially testable in isolation.

---

## 9. Local storage layer

Organised so the schema is obvious and framework types stay contained:

```
LocalStorage/
├── Entities/                          SwiftData @Model classes (the schema)
│   ├── CachedSearchPageEntity          page number + insertedAt + cascade → artworks
│   ├── CachedArtworkEntity             artwork fields + sortIndex (preserves API order)
│   ├── CachedArtworkDetailEntity       detail fields + insertedAt
│   └── CachedSearchMetadataEntity      singleton: totalPages
├── CachedSearchPage / CachedArtworkDetail   return envelopes (payload + insertedAt)
├── SearchResultsLocalStoreProtocol
├── ArtworkDetailLocalStoreProtocol    two focused protocols (ISP)
├── SwiftDataArtworkLocalStore         @ModelActor implementation of both
├── LocalStoreError / LocalStoreErrorMapper   SwiftData errors → domain errors
└── ArtworkCacheContainerFactory       builds the container; resilient recovery
```

Key decisions:

- **Two‑table page design.** `CachedSearchPageEntity` links a page number to its `insertedAt`;
  artworks hang off it via a cascade relationship, so replacing/deleting a page cleans its
  artworks automatically. `sortIndex` preserves API relevance order (SwiftData relationships are
  unordered).
- **`@ModelActor`** gives thread‑safe persistence off the main actor.
- **Injected clock (`DateProviding`)** so cache timestamps are deterministic in tests.
- **Resilient container creation.** A cache must never crash the app: `makeResilient()` tries the
  on‑disk store, wipes and retries a corrupt/incompatible store (this is also the
  schema‑migration policy — a format change just resets the rebuildable cache), and falls back to
  in‑memory if the disk is unusable. The app degrades instead of crashing.

---

## 10. UI & Accessibility, Light/Dark/High Contrast

- **System colours & text styles everywhere.** `Color.accentColor`, `.primary`/`.secondary`/
  `.tertiary`, `Color(.secondarySystemBackground)`, and Dynamic‑Type text styles (`.largeTitle`,
  `.headline`, `.subheadline`, `.body`, `.footnote`). Because nothing is hard‑coded, the app works
  correctly in **light mode, dark mode, and Increased Contrast** with no extra code, and scales
  with the user's Dynamic Type setting.
- **VoiceOver.** Each list row is a single accessibility element with a combined label
  ("_title, date_") and a hint ("Shows the artwork's details"); decorative images and chevrons are
  hidden from VoiceOver (`accessibilityHidden(true)`). Detail sections carry labels, and interactive
  controls have identifiers.
- **Accessibility identifiers** on all meaningful elements (`search.list`, `search.row.{id}`,
  `offlineBanner`, `waitingForConnectionView`, `detail.title`, `detail.descriptionToggle`, …),
  ready for UI automation.
- **Small screens.** Verified on **iPhone SE (3rd gen)**; long values (medium, dimensions,
  description) wrap instead of clipping. The detail hero image extends under the notch while the
  pull‑to‑refresh spinner stays in reachable space.

---

## 11. Data exploration

Before writing code, the API was explored with a helper repo:
**https://github.com/Ahmed23Adel/Tacx-assignemnet-helpers**

Findings:

- The artist's collection is **247 artworks** — far too many for a single screen, so the feed is
  **paginated** (20 per page, 13 pages).
- **245 / 247 items are clean.** Two exceptions in the search fields:
  - id **49156** — `date_display` is `null` (title and `image_id` present)
  - id **49212** — `image_id` is `null` (title and `date_display` present)
- **Detail fields** (`artist_display`, `date_display`, `medium_display`, `dimensions`,
  `place_of_origin`, `credit_line`, `image_id`) are **reliably present**, with the same two
  exceptions above and no new issues.
- **Field length:** `date_display` is short (max ~18 chars, e.g. `"1635, printed 1906"`), so it fits
  a chip; `medium_display` can be a full sentence, so it lives in a wrapping facts row.

---

## 12. Nullability strategy — building for a year from now

Although most fields are *currently* non‑null, the data is user‑contributed museum metadata that
changes over time. **My concern was future data:** if the museum later adds an artwork with a
missing field, an app that assumed the field was always present would break — a crash or a blank
screen in production, long after I'd stopped looking at it.

So I deliberately modelled **every optional‑in‑practice field as `String?`** and made the UI hide
each section independently when its value is `nil`. This costs a little unwrapping today but means
the app works whether the museum inserts new artworks with missing fields, changes which fields it
returns, or nothing changes at all. **I preferred to build it so I'm confident it works now *and*
a year from now**, rather than optimise for today's exact payload.

---

## 13. Testing

- **285 unit + integration tests**, ~**100% coverage of every business‑logic file** (models,
  networking, local storage, repositories, view models, coordinator, and the pure helpers). UI
  view bodies are excluded by design (they contain no logic and are exercised manually / are
  XCUITest territory).
- **The code was written to be testable**, which is *why* the coverage is achievable:
  - every dependency is an injected **protocol**, so each unit is tested against mocks;
  - **time** is injected (`DateProviding`) so the 5‑minute TTL boundary is asserted deterministically;
  - **connectivity** is a protocol with a controllable mock, so offline **parking** is tested in
    milliseconds instead of with real airplane mode;
  - error paths are made reachable via **seams** (e.g. the injectable HTML `parse` step, the
    injectable container `make`/`removeItem`), so even "framework can't‑fail" branches are covered;
  - **in‑memory SwiftData** containers make persistence tests fast and isolated.
- **Both unit and integration tests.** Pure logic is unit‑tested against mocks — that proves each
  unit's own decisions are correct in isolation, but it can't prove the *real* collaborators still
  cooperate the way the mocks assume. So a second layer of tests wires the real pieces together,
  with the wire replaced only at the outermost edge:
  - **`CachedArtworkRepositoryIntegrationTests`** — the real `CachedArtworkRepository` wired to a
    real `SwiftDataArtworkLocalStore` (in‑memory), a real `ArtworkRepository` +
    `AlamofireAPIRequester` (stubbed only at the wire via `MockURLProtocol`), and a real
    `NetworkMonitor` driven deterministically. It proves, against real persistence and real
    connectivity: cache‑first download‑then‑hit, TTL expiry triggering a real redownload,
    **page‑level cache independence** (a stale page must not evict a fresh neighbour — the core
    per‑page caching claim), real offline parking and reconnect‑triggered completion, `clearCache`
    actually wiping persisted rows, per‑artwork refresh only touching that artwork's row, and real
    server errors flowing through the full stack as `NetworkError`.
  - **`ViewModelSearchArtworksFullStackIntegrationTests`** — wires `ViewModelSearchArtworks` to
    that same real stack, closing the matching gap one layer up (view models had otherwise only
    ever seen a mock repository): initial load, offline‑then‑reconnect driving the real waiting
    state, pull‑to‑refresh through the real cache, and infinite scroll triggering a real second
    page download.
  - **`AlamofireAPIRequesterIntegrationTests`** — the real Alamofire `Session` over a stubbed
    `URLProtocol` (request building, JSON decoding, error mapping, all real).
  - **`LocalStorePersistenceIntegrationTests`** / **`NetworkMonitorLivePathIntegrationTests`** —
    real SwiftData recovery tested by planting a corrupt store file on disk; the real
    `NWPathMonitor` wiring exercised end‑to‑end.
  - **`LiveAPIIntegrationTests`** — a small set of tests against the real AIC API, skippable via
    `SKIP_LIVE_TESTS`, proving the end‑to‑end path actually works outside of any stub.

  Time in the integration suite is simulated the same way unit tests do it — by building a second
  repository instance against the **same** in‑memory container with a later injected clock — so
  the 5‑minute TTL boundary is proven without a real 5‑minute wait.
- Test files mirror the source layout (`AICTests/Networking`, `/LocalStorage`, `/Repositories`,
  `/Screens`, `/Core`, `/Coordination`, `/Integration`, plus `/Mocks` and `/Helpers`).


<p align="center">
  <img
    src="https://github.com/user-attachments/assets/b60f2c3d-37a6-488f-a134-07bb9225e6b7"
    alt="tests1"
    width="800"
  />
</p>

<p align="center">
  <img
    src="https://github.com/user-attachments/assets/5cfdc818-d702-476d-b5e8-636a1648fc35"
    alt="tests2"
    width="800"
  />
</p>


---

## 14. Debug logging & tracing

The app uses Apple's unified logging (`os.Logger`), not `print()`, at the points that matter most
for tracing the caching/offline behaviour with a debugger or Console.app attached — `print()`
output is unstructured scrollback with no severity and no way to filter; `os.Logger` output is
categorised, leveled, and stays useful in a release build instead of being something to strip out
later.

**`Core/AppLogger.swift`** defines five categories, each independently filterable (Xcode console,
or Console.app filtered by the app's bundle id as subsystem):

| Category | What it traces |
|---|---|
| `Cache` | Every caching decision: **HIT** (with cache age in seconds), **MISS/STALE**, download success/failure, `clearCache` / `refreshArtworkDetail` |
| `Connectivity` | Connectivity flips (`-> ONLINE` / `OFFLINE`), a call **parking** (with live waiter count), and parked calls being **resumed** or **cancelled** |
| `Network` | Every HTTP request out and response in, through the real Alamofire stack |
| `Storage` | The cache container's resilient‑recovery path — normal open, corrupt‑store wipe, or (at `.fault`, the loudest level) degrading to in‑memory |
| `ViewModel` | User‑triggered actions: appear, scroll‑triggered prefetch, retry (with which intent), pull‑to‑refresh, and every error actually shown to the user |

**Reading a real trace.** Scrolling near the end of the list while offline, then reconnecting,
produces exactly this story in order:

```
[ViewModel]    search: row 15/20 triggered prefetch of page 2
[Cache]        page 2: cache MISS/STALE — requesting network access
[Connectivity] call parking (offline) — 1 waiter(s) after this one
        … user reconnects …
[Connectivity] connectivity changed -> ONLINE
[Connectivity] resuming 1 parked call(s)
[Network]      -> GET /artworks/search ["page": "2", …]
[Network]      <- 200 /artworks/search
[Cache]        page 2: downloaded 20 artworks, totalPages=13
```

That single trace demonstrates, end to end, the two hardest‑to‑observe requirements in the
assignment: the request was parked while offline and resumed automatically on reconnect, and it
only reached the network because the cache had genuinely missed.

---

## 15. Performance profiling (Instruments — Time Profiler)

Beyond correctness, I ran the app through Xcode's **Time Profiler** while scrolling the search
feed to check the app isn't doing anything wasteful on the main thread.

### What it confirmed was healthy

- **Hangs: "No Graphs".** Zero detected across the whole trace.
- **Thermal state: Nominal** for the entire run — no sustained CPU pressure that would throttle
  the device or drain the battery unusually fast.
- **The main thread's time is spent where it should be.** ~83% of sampled main‑thread work
  resolves into `__CFRunLoopRun` → `_UIUpdateSequence…` → `CA::Layer::layout_and_display` — that's
  SwiftUI/UIKit's own layout‑and‑compositing loop doing its job while cells scroll into view, not
  app code being slow. In absolute terms the CPU graph shows clear idle gaps between spikes, not
  sustained load.



<p align="center">
  <img width="1255" height="952" alt="time-full" src="https://github.com/user-attachments/assets/d7a3f11e-17d6-4a5a-bb1e-9db623231c0d" />

  <br />
  <sub>Time Profiler overview — CPU usage, thermal state, and the Hangs instrument</sub>
</p>

### What it found: JPEG decoding running in periodic spikes

Zooming into one of the CPU spikes, the heaviest stack in that window was:

```
recode_all                    (AppleJPEG)
 └─ applejpeg_decode_image…    (AppleJPEG)
     └─ aj_mcu_decode_prog…    (AppleJPEG)
         └─ aj_prog_decode_AC_…(AppleJPEG)
```

That's the AIC image CDN serving **progressive JPEGs**, which decode in several passes and cost
noticeably more CPU than a baseline JPEG — one decode per artwork thumbnail/hero image as it
scrolls into view, which is why the CPU graph looks like a comb while scrolling.

<p align="center">
  <img width="542" height="800" alt="time-spike" src="https://github.com/user-attachments/assets/c38d728b-fa4a-4ef1-9de3-cbcb982253c5" />

  <br />
  <sub>Zoomed into a CPU spike — heaviest stack trace resolves into AppleJPEG decode frames</sub>
</p>

<p>
The image decoding work was running on a background thread, not the UI thread. In Instruments,
the stack appeared on <code>AIC (0x5676c1)</code> rather than <code>Main Thread</code>, which
confirmed that the work was being executed off the main thread and was not blocking the UI.
</p>

### The avoidable part

The image was decoded at **full downloaded size** even though it's displayed much smaller — the
843px hero image was fully decompressed into memory before SwiftUI ever scaled it down for layout,
and the same happened for every 200px list thumbnail rendered at 64pt. That's real, avoidable CPU
and memory that doesn't buy anything visually: the extra pixels are thrown away the instant
SwiftUI lays the image into its frame.

### The suggested fix

Kingfisher's `DownsamplingImageProcessor` uses ImageIO to decode the JPEG **directly at the
target display size** instead of decoding full‑size and downscaling afterward — cheaper CPU per
decode, and a decoded 64pt thumbnail bitmap costs kilobytes instead of megabytes.

### What was applied

`DownsamplingImageProcessor(size:)` on both `KFImage` call sites, sized in **pixels** (`points ×
displayScale`, read from `@Environment(\.displayScale)`:

- **`ArtworkRowView`** — downsamples to the 64pt row thumbnail's pixel size.
- **`ViewArtworkDetail`** — downsamples to the hero image's actual on‑screen size, read from
  `GeometryReader` rather than hard‑coded, so it's correct on every device width.

  
Both also set `.scaleFactor(displayScale)` so the *original* download stays in the disk cache while the *processed* (already‑downsampled) bitmap is what lives in the memory cache — re‑scrolling reuses the cheap version instead of re‑decoding.

---

## 16. Memory graph debugging (Xcode)

Beyond CPU, I ran Xcode's **Memory Graph Debugger** after a browsing session (launch → open a few
artwork detail screens → navigate back to the list) to check for retain cycles and leaked objects
around the composition root and the cache‑policy layer.

<p align="center">
<img width="874" height="615" alt="Screenshot 2026-07-13 at 2 26 07 AM" src="https://github.com/user-attachments/assets/4b67e0fe-1336-426a-a311-8ca4ef9cf328" />
  <br />
  <sub>Memory graph rooted at AppDependencies after opening and closing several artwork details</sub>
</p>

**Findings:**

- **No retain cycles.** Every arrow in the graph flows one direction — outward from
  `AppDependencies` into `NetworkMonitor` / `CachedArtworkRepository` and down into their
  collaborators. Nothing points back up toward an ancestor, and Xcode raises no leaked‑object
  warning for any node here.

---

## 17. Coding style

- **Protocol‑oriented + dependency injection** as the default; concrete types only at the edges,
  assembled in one composition root.
- **Small, single‑purpose functions and types**; display logic expressed as named computed
  properties rather than inline booleans in views.
- **`@Observable` (iOS 17 Observation)** for all view models; typed navigation path over
  `NavigationPath` for inspectability/testability.
- **Errors are domain types** conforming to `LocalizedError`, translated at each boundary so
  foreign error types never leak upward.
- **Force‑unwrap discipline:** used only on compile‑time‑known constants (a static URL literal, an
  in‑memory container that can only fail on a programmer error), always with a comment explaining
  why it's safe. No force‑unwrapping of runtime/field values.
- **Consistent naming** (`View…` / `ViewModel…`, `…Protocol`, `…Endpoint`/`…Response`,
  `Cached…Entity`) and per‑layer folders.

---

## 18. Dependencies

Managed with **Swift Package Manager** (resolve automatically on open):

| Package | Version | Why |
|---|---|---|
| **Alamofire** | 5.12.0 | Mature HTTP client with first‑class async/await and request adapters — used behind the `APIRequester` protocol so it stays swappable and is the only place that imports it. |
| **Kingfisher** | 8.10.0 | Battle‑tested async image loading **with disk + memory caching** — so thumbnails and hero images are cached for offline viewing too. Also provides the request‑modifier hook used to pass the AIC image CDN's Cloudflare bot check. |

Persistence uses Apple's **SwiftData** (no third‑party dependency).

---

## 19. Known limitations & possible next steps

Honest list of what a longer engagement would add:

- **UI tests.** Logic is fully unit‑tested; a small XCUITest smoke suite (launch → list → tap →
  detail → expand → refresh) would cover the view bodies and exercise the accessibility identifiers.
- **Localization.** User‑facing strings use `String(localized:)` and are ready for a string
  catalog, but only English is provided.
- **Data virtualization.** Loaded pages are currently retained for the lifetime of the screen,
  so memory usage grows as the user continues scrolling. For very large datasets, a sliding-window
  approach could keep only nearby pages in memory and reload older ones from cache when needed,
  keeping memory usage bounded.
---

## Assumptions

- One fixed featured artist (Rembrandt van Rijn), per "an artist of choice".
- The 5‑minute TTL applies per cache entry (page / detail), not globally.
- Offline behaviour follows the requirement literally: requests **park** rather than showing a
  hard error, and stale data is not shown for a request that must go to the network (valid cache
  is still shown, with an offline banner).
- Image URLs are built client‑side from `image_id` using the IIIF endpoint
  (`/full/200,/…` for thumbnails, `/full/843,/…` for the hero image).
