# Extension → Mobile Migration Plan

## 1. Executive Summary

ProxyM is a Chrome MV3 browser extension that manages HTTP/HTTPS/SOCKS4/SOCKS5 proxies with automatic rotation, bypass rules, geo-lookup, proxy health testing, and auto-detection of dead/slow/blocked proxies. The extension runs entirely client-side (no backend) using `chrome.storage.local` for persistence and `chrome.proxy` for system-level proxy application.

The **mobile app already exists** as a Flutter (Riverpod + GoRouter) client that talks to a Laravel backend. The extension's feature set is a **superset** of what's currently in the mobile app. This document maps every extension feature to its mobile equivalent and provides a phase-wise implementation plan.

**Key architectural difference:** The extension applies proxies at the OS/browser level via `chrome.proxy`. On mobile, there is **no equivalent system-wide proxy API** available to regular apps. The mobile app must either:

1. Use a **VPN-based approach** (`tun2socks` / `flutter_v2ray`) to route traffic through a proxy.
2. Act as a **proxy management dashboard** (store, test, rotate) while the actual proxy is consumed by a separate VPN app or the backend.
3. Use **per-app proxy configuration** where supported (HTTP clients like Dio can set proxy per-request).

> **Assumption:** The mobile app will serve as a management + testing dashboard, with proxy application handled via the backend API (which already exists). System-wide proxy routing is a Phase 3+ goal.

---

## 2. Extension Overview

| Attribute         | Value                                                                 |
|-------------------|-----------------------------------------------------------------------|
| **Name**          | ProxyM - Proxy Manager                                                |
| **Manifest**      | Chrome MV3                                                            |
| **Version**       | 1.0.1                                                                 |
| **Framework**     | React 18 + TypeScript + Vite                                          |
| **Dependencies**  | react, react-dom (runtime); @types/chrome, vite, typescript (dev)     |
| **Storage**       | `chrome.storage.local` (single key: `proxym_settings`)                |
| **Permissions**   | `proxy`, `storage`, `alarms`, `webRequest`, `webRequestAuthProvider`  |
| **Host perms**    | `<all_urls>`, ipwho.is, freeipapi.com, ip.guide                      |
| **Entry points**  | Background service worker + Popup UI                                  |
| **Styling**       | Single `popup.css` (1320 lines, light/dark theme via CSS vars)        |
| **No backend**    | Extension is fully self-contained; mobile already has Laravel backend |

---

## 3. Architecture Analysis

### 3.1 Extension Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      Chrome Extension                            │
│                                                                  │
│  ┌─────────────────┐    chrome.runtime     ┌──────────────────┐  │
│  │   Popup (React)  │ ←──── messages ────→ │  Background SW    │  │
│  │                   │                      │                    │  │
│  │  • SettingsPanel  │                      │  • proxyEngine     │  │
│  │  • ProxyForm      │                      │  • rotationEngine  │  │
│  │  • ProxyList      │                      │  • testEngine      │  │
│  │  • ProxyTester    │                      │  • authHandler     │  │
│  │  • AutoDetect     │                      │  • geoLookup       │  │
│  │  • SmartRotation  │                      │                    │  │
│  │  • BypassForm     │                      │  chrome.proxy.set  │  │
│  │  • BypassList     │                      │  chrome.alarms     │  │
│  │  • ProxyInfoPanel │                      │  chrome.webRequest │  │
│  └─────────────────┘                      └──────────────────┘  │
│           │                                         │            │
│           └──────── chrome.storage.local ───────────┘            │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 Mobile Architecture (Existing)

```
┌───────────────────────────────────────────────────────────────┐
│                     Flutter App (Riverpod)                      │
│                                                                │
│  Screens:                    Providers:           Services:     │
│  • LoginScreen               • authProvider        • ApiService │
│  • RegisterScreen            • proxyProvider        • WebSocket │
│  • HomeScreen                • planProvider                     │
│  • ProxyListScreen           • supportProvider                 │
│  • AddProxyScreen            • notificationProvider            │
│  • ProxyTestScreen                                             │
│  • BulkTestScreen            GoRouter (navigation)             │
│  • ProxyGroupsScreen                                           │
│  • ImportScreen              Firebase (FCM, auth)              │
│  • SettingsScreen                                              │
│  • PremiumScreen             Dio (HTTP) + secure_storage       │
│  • NotificationsScreen                                         │
│  • SupportListScreen                                           │
│  • ChatScreen                                                  │
└───────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────┐
│   Laravel Backend API    │
│   (SQLite, Sanctum)      │
└─────────────────────────┘
```

### 3.3 Key Architectural Differences

| Concern                | Extension                        | Mobile                             |
|------------------------|----------------------------------|------------------------------------|
| **Storage**            | `chrome.storage.local`           | Backend DB (via API) + local cache |
| **Proxy application**  | `chrome.proxy.settings.set()`    | Not available natively; VPN or per-request |
| **Background tasks**   | Service worker + `chrome.alarms` | Dart isolates / `workmanager`      |
| **Auth handler**       | `webRequest.onAuthRequired`      | Proxy auth embedded in Dio config  |
| **Message passing**    | `chrome.runtime.sendMessage`     | Riverpod state / method calls      |
| **Geo lookup**         | `fetch()` from SW (no CORS)      | Dio GET from app (or backend)      |
| **Theme**              | CSS custom properties            | `ThemeData` in MaterialApp         |
| **State management**   | React `useState` + callbacks     | Riverpod `Notifier`                |

---

## 4. Complete Feature Inventory

### 4.1 File-by-File Breakdown

#### Types Layer

| File | Purpose | Lines | Mobile Status |
|------|---------|-------|---------------|
| `types/proxy.types.ts` | `ProxyEntry`, `ProxyTestResult`, `ProxyFlags`, `BypassRule`, format types | 63 | Partially exists as `ProxyItem` in `proxy_provider.dart` — needs full parity |
| `types/message.types.ts` | Message types for popup↔background IPC | 45 | Not needed — mobile uses direct method calls |
| `types/settings.types.ts` | `AppSettings`, `RotationConfig`, `AutoDetectConfig`, defaults | 74 | **Missing entirely** — must be created |

#### Utils Layer

| File | Purpose | Lines | Mobile Status |
|------|---------|-------|---------------|
| `utils/constants.ts` | Storage key, alarm name, supported protocols | 4 | Equivalent constants needed |
| `utils/formatProxy.ts` | `formatProxyDisplay()`, `formatProxyShort()` | 18 | **Missing** — add as Dart util |
| `utils/parseProxyUri.ts` | Universal proxy string parser (URI, host:port, colon-quad, auth@host) + bulk parser | 225 | Backend has parser; mobile needs client-side parser for offline/preview |

#### Services Layer

| File | Purpose | Lines | Mobile Status |
|------|---------|-------|---------------|
| `services/storageService.ts` | `loadSettings()`, `saveSettings()` via chrome.storage | 25 | Replaced by API calls + local cache |
| `services/proxyService.ts` | `getSettings()`, `saveSettingsViaBackground()`, `rotateNow()` | 22 | Maps to API service methods |
| `services/messageService.ts` | `sendMessage()` wrapper for chrome.runtime | 16 | Not needed — direct Riverpod |
| `services/validationService.ts` | `detectBypassType()`, `validateBypassRule()`, ID generators | 30 | **Missing** — add as Dart util |

#### Background Layer

| File | Purpose | Lines | Mobile Status |
|------|---------|-------|---------------|
| `background/background.ts` | Main service worker: message router, startup, geo lookup (3 fallback APIs) | 247 | Geo lookup → Dart HTTP call; rotation → backend job or `workmanager` |
| `background/proxyEngine.ts` | `applyProxy()`, `clearProxy()` via `chrome.proxy.settings` | 66 | **Browser-only** — no direct mobile equivalent |
| `background/rotationEngine.ts` | `scheduleRotation()`, `cancelRotation()`, `rotateProxy()` with round-robin/random/weighted/sticky | 110 | Backend-driven or local timer via `workmanager` |
| `background/authHandler.ts` | `registerAuthHandler()` — auto-supplies proxy credentials on 407 | 70 | **Browser-only** — Dio handles auth per-request |
| `background/testEngine.ts` | `testProxy()` — connectivity, latency, DNS, download speed, geo, captcha/blocked detection | 135 | **Partially exists** (`proxy_provider.testProxy`); needs full parity |

#### Components Layer

| File | Purpose | Lines | Mobile Status |
|------|---------|-------|---------------|
| `components/SettingsPanel.tsx` | Enable toggle, rotation interval, current connection state, embeds `ProxyInfoPanel` | 144 | `SettingsScreen` exists but lacks connection state & rotation interval |
| `components/ProxyForm.tsx` | 3-tab form (URI / Manual / Bulk import), file import, drag-drop | 371 | `AddProxyScreen` + `ImportScreen` exist but simpler |
| `components/ProxyList.tsx` | Table of proxies with active indicator, protocol badge, auth status, last-used, remove/edit actions | 136 | `ProxyListScreen` exists — needs active proxy, last-used, protocol badges |
| `components/ProxyInfoPanel.tsx` | Expandable geo info (IP, country, city, ISP, timezone) with shimmer loading | 267 | **Missing entirely** |
| `components/CurrentConnection.tsx` | Connection status card (closed/waiting/connected) with protocol pill | 67 | **Missing entirely** |
| `components/ProxyTester.tsx` | Test individual or all proxies: latency, status, country, download, DNS, SSL | 184 | `ProxyTestScreen` + `BulkTestScreen` exist but show fewer metrics |
| `components/AutoDetect.tsx` | Toggle-based config for dead/slow/captcha/blocked/expired detection + scan now | 135 | **Missing entirely** |
| `components/SmartRotation.tsx` | Rotation mode (round-robin/random/weighted/sticky), trigger, failure handling | 147 | **Missing entirely** |
| `components/BypassForm.tsx` | Add bypass rules with format hints (hostname, wildcard, IP, CIDR, `<local>`) | 95 | **Missing entirely** |
| `components/BypassList.tsx` | Table of bypass rules with type badges | 95 | **Missing entirely** |

### 4.2 Complete Feature List

| # | Feature | Extension Files | Mobile Status |
|---|---------|----------------|---------------|
| F01 | **Add proxy (URI auto-detect)** | `ProxyForm.tsx`, `parseProxyUri.ts` | ✅ Partial (`AddProxyScreen`) |
| F02 | **Add proxy (manual form)** | `ProxyForm.tsx` | ✅ Partial |
| F03 | **Bulk import (textarea)** | `ProxyForm.tsx`, `parseProxyUri.ts` | ✅ Partial (`ImportScreen`) |
| F04 | **Bulk import (file upload)** | `ProxyForm.tsx` | ⚠️ Missing file picker |
| F05 | **Proxy list with active indicator** | `ProxyList.tsx` | ✅ Partial (no active indicator) |
| F06 | **Set active proxy** | `ProxyList.tsx`, `Popup.tsx` | ❌ Missing |
| F07 | **Remove proxy** | `ProxyList.tsx`, `Popup.tsx` | ✅ Exists |
| F08 | **Clear all proxies** | `ProxyList.tsx` | ❌ Missing |
| F09 | **Apply proxy (system-level)** | `proxyEngine.ts` | ❌ Browser-only |
| F10 | **Clear proxy (direct connection)** | `proxyEngine.ts` | ❌ Browser-only |
| F11 | **Proxy authentication (auto 407)** | `authHandler.ts` | ❌ Browser-only (Dio handles inline) |
| F12 | **Rotation: round-robin** | `rotationEngine.ts` | ❌ Missing |
| F13 | **Rotation: random** | `rotationEngine.ts` | ❌ Missing |
| F14 | **Rotation: weighted** | `rotationEngine.ts` | ❌ Missing |
| F15 | **Rotation: sticky session** | `rotationEngine.ts` | ❌ Missing |
| F16 | **Rotation trigger: time** | `rotationEngine.ts`, `background.ts` | ❌ Missing |
| F17 | **Rotation trigger: requests** | `settings.types.ts` (defined, not implemented in bg) | ❌ Missing |
| F18 | **Rotation trigger: tab-change** | `settings.types.ts` (defined, not implemented) | N/A — no browser tabs |
| F19 | **Rotation trigger: browser-restart** | `settings.types.ts` (defined, not implemented) | N/A |
| F20 | **Skip failed proxies in rotation** | `rotationEngine.ts` | ❌ Missing |
| F21 | **Cooldown before reuse** | `rotationEngine.ts` | ❌ Missing |
| F22 | **Retry count on failure** | `settings.types.ts` | ❌ Missing |
| F23 | **Test single proxy** | `testEngine.ts`, `ProxyTester.tsx` | ✅ Partial (fewer metrics) |
| F24 | **Test all proxies** | `testEngine.ts`, `ProxyTester.tsx` | ✅ Partial (`BulkTestScreen`) |
| F25 | **Latency measurement** | `testEngine.ts` | ✅ Exists |
| F26 | **Download speed test** | `testEngine.ts` | ❌ Missing |
| F27 | **DNS latency test** | `testEngine.ts` | ❌ Missing |
| F28 | **SSL validation** | `testEngine.ts` | ❌ Missing |
| F29 | **Captcha detection** | `testEngine.ts` | ❌ Missing |
| F30 | **Blocked proxy detection** | `testEngine.ts` | ❌ Missing |
| F31 | **DNS leak detection** | `testEngine.ts` | ❌ Missing |
| F32 | **Expired credentials detection** | `testEngine.ts` | ❌ Missing |
| F33 | **Auto-detect scan (all proxies)** | `AutoDetect.tsx`, `background.ts` | ❌ Missing |
| F34 | **Auto-remove dead proxies** | `AutoDetect.tsx` (config flag) | ❌ Missing |
| F35 | **Auto-skip flagged in rotation** | `AutoDetect.tsx`, `rotationEngine.ts` | ❌ Missing |
| F36 | **Slow threshold config** | `AutoDetect.tsx` | ❌ Missing |
| F37 | **Geo lookup (IP, country, city, ISP, TZ)** | `background.ts`, `ProxyInfoPanel.tsx` | ❌ Missing |
| F38 | **Country flag emoji** | `ProxyInfoPanel.tsx` | ❌ Missing |
| F39 | **Connection state display** | `SettingsPanel.tsx` | ❌ Missing |
| F40 | **Bypass rules (hostname)** | `BypassForm.tsx`, `BypassList.tsx`, `validationService.ts` | ❌ Missing |
| F41 | **Bypass rules (wildcard)** | Same | ❌ Missing |
| F42 | **Bypass rules (IP)** | Same | ❌ Missing |
| F43 | **Bypass rules (CIDR)** | Same | ❌ Missing |
| F44 | **Bypass rules (<local>)** | Same | ❌ Missing |
| F45 | **Light / Dark theme toggle** | `Popup.tsx`, CSS custom props | ✅ Dark only — needs light + toggle |
| F46 | **Enable/disable global toggle** | `SettingsPanel.tsx` | ❌ Missing |
| F47 | **Rotation interval config** | `SettingsPanel.tsx` | ❌ Missing |
| F48 | **Proxy weight config (1-10)** | `proxy.types.ts` (field exists) | ❌ Missing |
| F49 | **Saving indicator** | `Popup.tsx` ("Saving" pill) | ❌ Missing |
| F50 | **Error banner** | `Popup.tsx` (global error bar) | ❌ Missing |

---

## 5. Dependency Analysis

### 5.1 Extension Dependencies

| Dependency | Role | Mobile Equivalent |
|-----------|------|-------------------|
| `react` / `react-dom` | UI framework | Flutter widgets (already in use) |
| `@types/chrome` | Chrome API types | N/A — no chrome APIs on mobile |
| `vite` | Build tool | Flutter build system |
| `typescript` | Type safety | Dart's type system |

### 5.2 Chrome API Dependencies

| Chrome API | Used In | Mobile Replacement |
|-----------|---------|-------------------|
| `chrome.storage.local` | `storageService.ts` | `shared_preferences` / backend API |
| `chrome.proxy.settings` | `proxyEngine.ts` | VPN tunnel or per-request Dio proxy |
| `chrome.alarms` | `rotationEngine.ts`, `background.ts` | `workmanager` / `Timer` |
| `chrome.runtime.sendMessage` | All popup↔background IPC | Direct Riverpod method calls |
| `chrome.runtime.onInstalled` | `background.ts` | App lifecycle events |
| `chrome.runtime.onStartup` | `background.ts` | App startup in `main()` |
| `chrome.webRequest.onAuthRequired` | `authHandler.ts` | Dio interceptors with proxy auth |
| `chrome.runtime.lastError` | Error handling everywhere | Dart exceptions |

### 5.3 External API Dependencies

| API | Purpose | Used In | Mobile Approach |
|-----|---------|---------|-----------------|
| `ipwho.is` | Geo lookup (primary) | `background.ts` | Same — HTTP GET via Dio |
| `ip.guide` | Geo lookup (fallback 1) | `background.ts` | Same |
| `freeipapi.com` | Geo lookup (fallback 2) | `background.ts` | Same |
| `httpbin.org/get` | Proxy connectivity test | `testEngine.ts` | Same |
| `dns.google/resolve` | DNS latency test | `testEngine.ts` | Same |
| `speed.cloudflare.com` | Download speed test | `testEngine.ts` | Same |

---

## 6. Data Flow

### 6.1 Extension Data Flow

```
User action (Popup UI)
  → React setState()
  → persist() → sendMessage(SAVE_SETTINGS)
  → Background handleMessage()
  → saveSettings(chrome.storage.local)
  → applyProxy(chrome.proxy.settings.set)
  → scheduleRotation(chrome.alarms.create)
```

### 6.2 Mobile Data Flow (Target)

```
User action (Flutter UI)
  → Riverpod Notifier method
  → ApiService.client.post('/proxies/settings')
  → Laravel validates + stores in DB
  → Response updates Riverpod state
  → UI rebuilds

Background rotation:
  → workmanager periodic task
  → Calls rotateProxy() on backend
  → Push notification / local state update
```

### 6.3 State Shape

The extension stores everything in a single `AppSettings` object:

```typescript
{
  enabled: boolean,
  rotationIntervalMinutes: number,
  activeProxyId: string | null,
  proxies: ProxyEntry[],          // with testResult, weight, lastUsed
  bypassRules: BypassRule[],
  theme: "light" | "dark",
  rotation: RotationConfig,       // mode, trigger, intervals, failure handling
  autoDetect: AutoDetectConfig,   // detection flags, thresholds, auto actions
}
```

The mobile app should maintain this in Riverpod state, synced with the backend.

---

## 7. UI Mapping

| Extension UI Element | Mobile Screen / Widget |
|---------------------|----------------------|
| Popup header (logo, theme toggle, status badge) | `AppBar` with theme switcher in `ShellScreen` |
| `SettingsPanel` → enable toggle, rotation interval | `SettingsScreen` → add toggle section + interval picker |
| `SettingsPanel` → current connection (closed/waiting/connected) | `HomeScreen` → connection status card |
| `ProxyInfoPanel` → geo tiles (IP, country, ISP, TZ) | `HomeScreen` → expandable info card or `ProxyDetailScreen` |
| `ProxyForm` → URI / Manual / Bulk tabs | `AddProxyScreen` (already tabbed) — add URI auto-detect |
| `ProxyForm` → file import button + drag-drop | `ImportScreen` — add `file_picker` package |
| `ProxyList` → table with active dot, protocol badge | `ProxyListScreen` — enhance with badges and active state |
| `ProxyTester` → collapsible, test one / test all | `ProxyTestScreen` + `BulkTestScreen` — add more metrics |
| `AutoDetect` → collapsible, toggle rows, scan now | **New:** `AutoDetectScreen` or section in `SettingsScreen` |
| `SmartRotation` → mode buttons, trigger config | **New:** `RotationSettingsScreen` or section in `SettingsScreen` |
| `BypassForm` → input + format hints | **New:** `BypassRulesScreen` |
| `BypassList` → table with type badges | Same screen, list section |
| Footer (branding, links) | Already in shell / about page |

---

## 8. Mobile Architecture

### 8.1 New Files Needed

```
mobile/lib/
├── models/
│   ├── proxy_entry.dart          ← Full ProxyEntry (port F01-F48)
│   ├── proxy_test_result.dart    ← TestResult + Flags
│   ├── bypass_rule.dart          ← BypassRule + BypassType
│   ├── rotation_config.dart      ← RotationConfig
│   ├── auto_detect_config.dart   ← AutoDetectConfig
│   └── app_settings.dart         ← Full AppSettings
├── utils/
│   ├── proxy_parser.dart         ← parseProxyUri() + bulk parser
│   ├── proxy_formatter.dart      ← formatProxyDisplay/Short
│   ├── bypass_validator.dart     ← validateBypassRule + detectType
│   └── country_flag.dart         ← countryFlag() emoji util
├── services/
│   ├── geo_service.dart          ← ipwho.is / ip.guide / freeipapi
│   └── proxy_test_service.dart   ← Full test engine (latency, speed, DNS, SSL, captcha)
├── providers/
│   ├── settings_provider.dart    ← AppSettings state
│   ├── rotation_provider.dart    ← Rotation logic + timer
│   └── auto_detect_provider.dart ← Auto-detect scan logic
└── screens/
    ├── home/
    │   └── widgets/
    │       ├── connection_status_card.dart
    │       └── proxy_info_panel.dart
    ├── proxies/
    │   └── widgets/
    │       ├── proxy_card.dart           ← Enhanced with badges
    │       └── test_result_row.dart
    ├── settings/
    │   └── widgets/
    │       ├── rotation_settings.dart
    │       ├── auto_detect_settings.dart
    │       └── bypass_rules_section.dart
    └── bypass/
        └── bypass_rules_screen.dart
```

### 8.2 Reusable Modules (Port Directly)

These modules contain pure logic with no browser API dependencies and can be ported to Dart almost line-for-line:

1. **`parseProxyUri.ts`** → `proxy_parser.dart` — all 4 format parsers + bulk parser
2. **`formatProxy.ts`** → `proxy_formatter.dart` — display formatting
3. **`validationService.ts`** → `bypass_validator.dart` — bypass rule validation
4. **`constants.ts`** → `constants.dart` — protocol list, storage keys
5. **`settings.types.ts`** (defaults) → `app_settings.dart` — default configs

### 8.3 Modules Requiring Adaptation

1. **`testEngine.ts`** → `proxy_test_service.dart` — Replace `fetch()` with Dio, but same test URLs and logic
2. **`rotationEngine.ts`** → `rotation_provider.dart` — Replace chrome.alarms with `Timer` / `workmanager`
3. **`background.ts` geo functions** → `geo_service.dart` — Replace `fetch()` with Dio, same 3-API fallback

### 8.4 Modules Not Needed on Mobile

1. **`messageService.ts`** — Chrome IPC; mobile uses Riverpod directly
2. **`storageService.ts`** — `chrome.storage.local`; mobile uses API + local cache
3. **`proxyEngine.ts`** — `chrome.proxy.settings`; no mobile equivalent for regular apps
4. **`authHandler.ts`** — `webRequest.onAuthRequired`; Dio handles proxy auth inline

---

## 9. Browser API Replacement Strategy

| Browser API | What It Doe## 10. Phase-wise Implementation Plan (Android)

> Every extension feature (F01–F50) is covered below. Each phase lists exactly **what** gets built, **how** it works on Android, the **Dart code approach**, **packages needed**, and **files created/modified**.

---

### Phase 1 — Data Models & Core Utils

**Covers:** F01–F04 (parsing foundation), F40–F44 (bypass types), F48 (proxy weight)

**Goal:** Port every TypeScript type, parser, validator, and formatter to Dart. Zero browser APIs — pure Dart logic.

#### What Gets Built

**1. Proxy model** — `mobile/lib/models/proxy_entry.dart` [NEW]

Port from `types/proxy.types.ts`. Direct 1:1 translation:

```dart
enum ProxyProtocol { http, https, socks4, socks5 }
enum ProxyTestStatus { untested, ok, slow, dead, blocked, leaked, expired }

class ProxyFlags {
  final bool dead, slow, captcha, blocked, credentialsExpired, dnsLeak;
  // fromJson / toJson
}

class ProxyTestResult {
  final int testedAt;
  final int? latencyMs, downloadKbps, uploadKbps, dnsMs;
  final bool? sslValid;
  final String? country, ip;
  final ProxyTestStatus status;
  final ProxyFlags flags;
  // fromJson / toJson
}

class ProxyEntry {
  final String id;
  final ProxyProtocol protocol;
  final String host;
  final int port;
  final String? username, password;
  final String raw;
  final int addedAt;
  final int? lastUsed;
  final int? weight; // 1-10 for weighted rotation
  final ProxyTestResult? testResult;
  // fromJson / toJson / copyWith
}
```

**Android implementation:** Pure Dart class. JSON serialization via hand-written `fromJson`/`toJson` (no codegen needed — Ponytail: no unnecessary deps). The extension's `ProxyEntry` has 11 fields — Dart version matches exactly.

---

**2. Bypass model** — `mobile/lib/models/bypass_rule.dart` [NEW]

```dart
enum BypassType { local, wildcard, ip, cidr, hostname }

class BypassRule {
  final String id, pattern;
  final BypassType type;
  final int addedAt;
  // fromJson / toJson
}
```

---

**3. Rotation config** — `mobile/lib/models/rotation_config.dart` [NEW]

```dart
enum RotationMode { roundRobin, random, weighted, sticky }
enum RotationTrigger { time, requests, tabChange, browserRestart }
// tabChange & browserRestart kept for API compat but only time/requests used on mobile

class RotationConfig {
  final RotationMode mode;
  final RotationTrigger trigger;
  final int intervalMinutes, intervalRequests;
  final bool skipFailed;
  final int retryCount, cooldownMinutes, stickySessionMinutes;

  static const defaultConfig = RotationConfig(
    mode: RotationMode.roundRobin,
    trigger: RotationTrigger.time,
    intervalMinutes: 1,
    intervalRequests: 100,
    skipFailed: true,
    retryCount: 2,
    cooldownMinutes: 5,
    stickySessionMinutes: 30,
  );
}
```

---

**4. Auto-detect config** — `mobile/lib/models/auto_detect_config.dart` [NEW]

```dart
class AutoDetectConfig {
  final bool enabled, deadProxy, slowProxy, captchaProxy, blockedProxy;
  final bool expiredCredentials, autoRemoveDead, autoSkipFlagged;
  final int slowThresholdMs;

  static const defaultConfig = AutoDetectConfig(
    enabled: true, deadProxy: true, slowProxy: true,
    slowThresholdMs: 3000, captchaProxy: true, blockedProxy: true,
    expiredCredentials: true, autoRemoveDead: false, autoSkipFlagged: true,
  );
}
```

---

**5. App settings** — `mobile/lib/models/app_settings.dart` [NEW]

```dart
class AppSettings {
  final bool enabled;
  final int rotationIntervalMinutes;
  final String? activeProxyId;
  final List<ProxyEntry> proxies;
  final List<BypassRule> bypassRules;
  final String theme; // "light" | "dark"
  final RotationConfig rotation;
  final AutoDetectConfig autoDetect;
  // fromJson / toJson / copyWith / DEFAULT_SETTINGS
}
```

---

**6. Proxy parser** — `mobile/lib/utils/proxy_parser.dart` [NEW]

Port from `utils/parseProxyUri.ts` (225 lines). The extension supports 4 input formats — all port to Dart identically:

| Format | Extension Function | Dart Equivalent |
|--------|-------------------|-----------------|
| `protocol://[user:pass@]host:port` | `parseUri()` | Same logic, use `Uri.decodeComponent()` instead of `decodeURIComponent()` |
| `host:port` | `parseHostPort()` | Same — `lastIndexOf(':')` to split |
| `host:port:user:pass` | `parseColonQuad()` | Same — `split(':')` and validate 4 parts |
| `user:pass@host:port` | `parseAuthAtHostPort()` | Same — `lastIndexOf('@')` to split |

Auto-detect (`parseProxyUri()`) uses the same decision tree: `hasScheme()` → `isColonQuad()` → `hasAtSign()` → `parseHostPort()`.

Bulk parser (`parseBulkProxies()`) splits on `\n`, skips `#` and `//` comments, calls `parseProxyUri()` per line.

**Android note:** No changes needed — `String.split()`, `int.parse()`, `RegExp` all work identically in Dart.

---

**7. Proxy formatter** — `mobile/lib/utils/proxy_formatter.dart` [NEW]

```dart
String formatProxyDisplay(ProxyEntry p) {
  final auth = p.username != null
    ? (p.password != null ? '${p.username}:****@' : '${p.username}@')
    : '';
  return '${p.protocol.name}://$auth${p.host}:${p.port}';
}

String formatProxyShort(ProxyEntry p) => '${p.host}:${p.port}';
```

---

**8. Bypass validator** — `mobile/lib/utils/bypass_validator.dart` [NEW]

Port from `services/validationService.ts`. Same regex patterns:

```dart
BypassType detectBypassType(String pattern) {
  if (pattern == '<local>') return BypassType.local;
  if (pattern.startsWith('*.')) return BypassType.wildcard;
  if (RegExp(r'^[\d.]+/\d+$').hasMatch(pattern)) return BypassType.cidr;
  if (RegExp(r'^[\d.]+$').hasMatch(pattern)) return BypassType.ip;
  return BypassType.hostname;
}
```

---

**9. Country flag** — `mobile/lib/utils/country_flag.dart` [NEW]

```dart
String countryFlag(String code) {
  if (code.length != 2) return '';
  return String.fromCharCodes(
    code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65),
  );
}
```

---

**10. Constants** — `mobile/lib/utils/constants.dart` [NEW]

```dart
const supportedProtocols = ['http', 'https', 'socks4', 'socks5'];
const storageKey = 'proxym_settings';
const rotationAlarmName = 'proxym_rotation';
```

#### New Packages

None. Pure Dart.

#### Acceptance Criteria
- [ ] All models round-trip through JSON without data loss
- [ ] Parser handles all 4 formats + IPv6 `[::1]:port` + URL-encoded auth
- [ ] `parseBulkProxies()` returns entries + errors with line numbers
- [ ] Bypass validator rejects spaces, invalid wildcards, malformed CIDR

---

### Phase 2 — Settings Provider & Proxy CRUD

**Covers:** F01 (URI add), F02 (manual add), F05 (proxy list), F06 (set active), F07 (remove), F08 (clear all), F46 (enable/disable), F47 (rotation interval), F49 (saving indicator), F50 (error banner)

**Goal:** Replace the thin `ProxyItem` model with full `ProxyEntry`, add a settings provider, and wire up CRUD with the backend.

#### What Gets Built

**1. Upgrade proxy provider** — `mobile/lib/providers/proxy_provider.dart` [MODIFY]

Replace `ProxyItem` with `ProxyEntry` from Phase 1. The existing provider fetches from `/api/proxies` — keep that, but deserialize into the full model:

```dart
class ProxyNotifier extends Notifier<List<ProxyEntry>> {
  Future<void> addProxy(String rawProxy) async {
    // Client-side parse first (instant validation + preview)
    final entry = parseProxyUri(rawProxy);
    // Then send to backend
    final response = await _api.client.post('/proxies', data: entry.toJson());
    state = [...state, ProxyEntry.fromJson(response.data)];
  }

  void setActive(String id) {
    ref.read(settingsProvider.notifier).update(activeProxyId: id);
  }

  void clearAll() {
    state = [];
    ref.read(settingsProvider.notifier).update(proxies: [], activeProxyId: null);
  }
}
```

**Android note:** The `addProxy` method now does client-side parsing before the API call. This gives instant error feedback (same UX as the extension's `ProxyForm.tsx`) without a network round-trip.

---

**2. Settings provider** — `mobile/lib/providers/settings_provider.dart` [NEW]

This is the mobile equivalent of the extension's single `AppSettings` blob in `chrome.storage.local`:

```dart
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(() {
  return SettingsNotifier();
});

class SettingsNotifier extends Notifier<AppSettings> {
  final _prefs = SharedPreferencesAsync();

  @override
  AppSettings build() {
    _loadCached();
    return AppSettings.defaultSettings;
  }

  Future<void> _loadCached() async {
    final json = await _prefs.getString(storageKey);
    if (json != null) state = AppSettings.fromJson(jsonDecode(json));
    // Then fetch fresh from backend
    _syncFromBackend();
  }

  Future<void> update({/* all optional fields */}) async {
    state = state.copyWith(/* fields */);
    // Persist locally (instant)
    await _prefs.setString(storageKey, jsonEncode(state.toJson()));
    // Sync to backend (async, fire-and-forget with retry)
    _syncToBackend();
  }
}
```

**Android implementation:**
- `shared_preferences` stores the full `AppSettings` JSON as a local cache
- On startup: load cache instantly → then fetch from backend to reconcile
- On change: write cache immediately (for speed) → POST to backend (for persistence)
- This mirrors the extension's `chrome.storage.local.get/set` pattern exactly

**How `chrome.storage.local` maps to Android:**

| Extension | Android |
|-----------|---------|
| `chrome.storage.local.get(key)` | `SharedPreferences.getString(key)` |
| `chrome.storage.local.set({key: value})` | `SharedPreferences.setString(key, jsonEncode(value))` |
| `chrome.storage.onChanged` listener | Riverpod auto-rebuilds when `state` changes |

---

**3. Active proxy derived provider** — same file

```dart
final activeProxyProvider = Provider<ProxyEntry?>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.enabled || settings.activeProxyId == null) return null;
  return settings.proxies.where((p) => p.id == settings.activeProxyId).firstOrNull;
});
```

---

**4. Saving indicator + error banner** — `mobile/lib/providers/settings_provider.dart`

```dart
final savingStateProvider = StateProvider<bool>((ref) => false);
final saveErrorProvider = StateProvider<String?>((ref) => null);
```

Show in `ShellScreen` as a `SnackBar` or overlay `Banner`, just like the extension's `saving` pill and `global-error` bar in `Popup.tsx`.

---

**5. Add proxy screen upgrade** — `mobile/lib/screens/proxies/add_proxy_screen.dart` [MODIFY]

Add the URI auto-detect tab from the extension's `ProxyForm.tsx`:

- **URI tab**: Single `TextField` + protocol dropdown. On submit, call `parseProxyUri()`. If it throws, show the error message. If it succeeds, show the parsed preview and add.
- **Manual tab**: Already exists — add protocol dropdown (http/https/socks4/socks5).
- **Bulk tab**: Already in `ImportScreen` — wire up `parseBulkProxies()` for client-side parsing.

---

**6. Proxy list upgrade** — `mobile/lib/screens/proxies/proxy_list_screen.dart` [MODIFY]

Add from extension's `ProxyList.tsx`:
- Active proxy indicator (green dot like `row-dot.active`)
- Tap to set active (like `onClick={() => onSetActive(proxy.id)}`)
- Protocol badge chip (`Chip(label: 'SOCKS5')` with protocol-specific color)
- Auth icon (checkmark if `username != null`)
- Last used relative time (`timeAgo()` function — same logic)
- "Clear All" button in app bar

#### New Packages

```yaml
# pubspec.yaml
dependencies:
  shared_preferences: ^2.2.0  # local settings cache
```

#### Acceptance Criteria
- [ ] URI input auto-detects format and shows parsed preview
- [ ] Proxy list shows active indicator, protocol badge, auth status
- [ ] Tap proxy to set as active — persists to backend + local cache
- [ ] "Clear All" removes all proxies
- [ ] Settings persist across app kill and restart (via shared_preferences)
- [ ] Saving pill shows during API calls, error banner on failure

---

### Phase 3 — Proxy Testing Engine

**Covers:** F23 (test single), F24 (test all), F25 (latency), F26 (download speed), F27 (DNS latency), F28 (SSL), F29 (captcha detect), F30 (blocked detect), F31 (DNS leak), F32 (expired creds)

**Goal:** Port the full `testEngine.ts` to Dart. On Android, the key difference is that we can't rely on the system proxy being active — we must explicitly route test requests through the proxy.

#### How Proxy Testing Works on Android

The extension's `testEngine.ts` calls `fetch(url)` and the request automatically goes through `chrome.proxy` (already applied system-wide). On Android, we create an `HttpClient` with the proxy configured explicitly:

```dart
HttpClient _createProxiedClient(ProxyEntry proxy) {
  final client = HttpClient();

  // Route through the proxy
  client.findProxy = (uri) {
    final scheme = proxy.protocol == ProxyProtocol.socks5 ? 'SOCKS5'
        : proxy.protocol == ProxyProtocol.socks4 ? 'SOCKS4'
        : 'PROXY';
    return '$scheme ${proxy.host}:${proxy.port}';
  };

  // Supply auth if needed (replaces chrome.webRequest.onAuthRequired)
  if (proxy.username != null && proxy.password != null) {
    client.addProxyCredentials(
      proxy.host, proxy.port, 'basic',
      HttpClientBasicCredentials(proxy.username!, proxy.password!),
    );
  }

  client.connectionTimeout = const Duration(milliseconds: 8000);
  return client;
}
```

**This is how `authHandler.ts` maps to Android:** Instead of a global `webRequest.onAuthRequired` listener, we add credentials directly to the `HttpClient` instance via `addProxyCredentials()`. Same outcome — proxy gets authenticated — different mechanism.

#### What Gets Built

**1. Test service** — `mobile/lib/services/proxy_test_service.dart` [NEW]

Direct port of `testEngine.ts`. Same test URLs, same signature detection:

```dart
class ProxyTestService {
  static const _testUrls = {
    'https': 'https://httpbin.org/get',
    'dns': 'https://dns.google/resolve?name=example.com&type=A',
    'speed': 'https://speed.cloudflare.com/__down?bytes=100000',
    'geo': 'https://ipwho.is/',
  };

  static const _captchaSignatures = [
    'captcha', 'cf-chl', 'challenge', 'are you human',
    'ddos-guard', 'datadome', 'recaptcha',
  ];

  static const _blockedSignatures = [
    'access denied', '403 forbidden', 'blocked', 'unavailable',
    'restricted', 'your ip has been',
  ];

  Future<ProxyTestResult> testProxy(ProxyEntry proxy) async {
    final client = _createProxiedClient(proxy);
    final flags = ProxyFlags.allFalse();

    int? latencyMs, downloadKbps, dnsMs;
    bool? sslValid;
    String? country, ip;

    // 1. Connectivity + latency (same as testEngine.ts lines 40-59)
    try {
      final sw = Stopwatch()..start();
      final req = await client.getUrl(Uri.parse(_testUrls['https']!));
      final res = await req.close();
      latencyMs = sw.elapsedMilliseconds;
      sslValid = res.statusCode == 200;

      if (res.statusCode == 407) {
        flags.credentialsExpired = true;
      } else if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final lower = body.toLowerCase();
        if (_captchaSignatures.any(lower.contains)) flags.captcha = true;
        if (_blockedSignatures.any(lower.contains)) flags.blocked = true;
      } else {
        flags.blocked = true;
      }
    } catch (_) {
      flags.dead = true;
    }

    if (flags.dead) return _buildResult(flags, 'dead', ...);

    // 2. Slow check (same threshold: 3000ms)
    if (latencyMs != null && latencyMs > 3000) flags.slow = true;

    // 3. DNS latency
    try {
      final sw = Stopwatch()..start();
      final req = await client.getUrl(Uri.parse(_testUrls['dns']!));
      await req.close();
      dnsMs = sw.elapsedMilliseconds;
    } catch (_) {}

    // 4. Download speed
    try {
      final sw = Stopwatch()..start();
      final req = await client.getUrl(Uri.parse(_testUrls['speed']!));
      final res = await req.close();
      final bytes = await res.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final elapsed = sw.elapsedMilliseconds / 1000;
      downloadKbps = (bytes / 1024 / elapsed).round();
    } catch (_) {}

    // 5. Geo + DNS leak check
    try {
      final req = await client.getUrl(Uri.parse(_testUrls['geo']!));
      final res = await req.close();
      final d = jsonDecode(await res.transform(utf8.decoder).join());
      ip = d['ip'] ?? proxy.host;
      country = d['country_code'];
      if (ip == proxy.host) flags.dnsLeak = true;
    } catch (_) {}

    client.close();
    return _buildResult(flags, _deriveStatus(flags, latencyMs), ...);
  }
}
```

**Key Android difference:** We use `HttpClient` (dart:io) instead of `fetch()`. The `findProxy` callback routes through the proxy being tested. On the extension, the system proxy was already active — on Android, we configure it per-request. Same test logic, different transport.

---

**2. Bulk test** — Same service, add `testAll()`:

```dart
Future<Map<String, ProxyTestResult>> testAll(List<ProxyEntry> proxies) async {
  final results = <String, ProxyTestResult>{};
  // Run in parallel with a pool limit (avoid socket exhaustion)
  final pool = Pool(5); // from package:pool
  await Future.wait(proxies.map((p) => pool.withResource(() async {
    results[p.id] = await testProxy(p);
  })));
  return results;
}
```

---

**3. Update test screens** — `proxy_test_screen.dart` + `bulk_test_screen.dart` [MODIFY]

Show all 6 metrics from the extension's `ProxyTester.tsx`:

| Metric | Extension shows | Android widget |
|--------|----------------|----------------|
| Status | Colored badge (OK/Slow/Dead/Blocked/Expired) | `Chip` with `statusColor()` |
| Latency | `${latencyMs}ms` | `Text` |
| Country | Country code | `Text` + `countryFlag()` |
| Download | `${downloadKbps}KB/s` | `Text` |
| DNS | `${dnsMs}ms` | `Text` |
| SSL | ✓ or ✗ | `Icon` |

#### New Packages

```yaml
dependencies:
  pool: ^1.5.0  # throttle concurrent test requests
```

#### Acceptance Criteria
- [ ] Test single proxy returns all 6 metrics
- [ ] Captcha detection catches common signatures
- [ ] Blocked detection catches 403/access-denied pages
- [ ] 407 status correctly flags `credentialsExpired`
- [ ] DNS leak detection compares resolved IP to proxy host
- [ ] Bulk test runs max 5 concurrent with progress indicator
- [ ] Test results persist to proxy entry via settings provider

---

### Phase 4 — Geo Lookup & Connection Info

**Covers:** F37 (geo lookup), F38 (country flag), F39 (connection state display)

**Goal:** Port the 3-API fallback geo lookup and the connection status UI.

#### How Geo Lookup Works on Android

The extension runs geo lookups in the service worker (no CORS restrictions). On Android, there are **no CORS restrictions at all** — so it's actually simpler. Just use Dio:

```dart
class GeoService {
  static final _dio = Dio()..options.connectTimeout = Duration(seconds: 6);

  static Future<GeoData> fetchGeoInfo(String host) async {
    // Same 3-API fallback chain as background.ts lines 168-246
    final apis = [
      () => _fetchFromIpWho(host),
      () => _fetchFromIpGuide(host),
      () => _fetchFromFreeIpApi(host),
    ];

    String lastErr = 'All geo APIs failed';
    for (final api in apis) {
      try { return await api(); }
      catch (e) { lastErr = e.toString(); }
    }
    throw Exception(lastErr);
  }

  static Future<GeoData> _fetchFromIpWho(String host) async {
    final res = await _dio.get('https://ipwho.is/${Uri.encodeComponent(host)}');
    final d = res.data;
    if (d['success'] == false) throw Exception(d['message'] ?? 'ipwho.is failed');
    return GeoData(
      ip: d['ip'] ?? host,
      country: d['country'] ?? 'Unknown',
      countryCode: d['country_code'] ?? '',
      city: d['city'] ?? 'Unknown',
      region: d['region'] ?? '',
      isp: d['connection']?['isp'] ?? d['connection']?['org'] ?? 'Unknown',
      timezone: d['timezone']?['id'] ?? 'Unknown',
    );
  }
  // _fetchFromIpGuide and _fetchFromFreeIpApi — same pattern
}
```

**Chrome API replacement:** `fetch()` from service worker → `Dio.get()`. No CORS on mobile, so no need for the service-worker proxy trick.

---

**Connection status card** — `mobile/lib/screens/home/widgets/connection_status_card.dart` [NEW]

Port from `SettingsPanel.tsx` lines 78-134. Three states:

```dart
enum ConnectionState { closed, waiting, connected }

ConnectionState getConnectionState(AppSettings settings) {
  if (!settings.enabled) return ConnectionState.closed;
  final hasActive = settings.proxies.any((p) => p.id == settings.activeProxyId);
  return hasActive ? ConnectionState.connected : ConnectionState.waiting;
}
```

Widget shows:
- **Closed:** Shield-off icon + "Proxy manager is disabled"
- **Waiting:** Spinner + "Connecting to proxy..." or "Add a proxy to get started"
- **Connected:** Checkmark + protocol pill + `host:port`

---

**Proxy info panel** — `mobile/lib/screens/home/widgets/proxy_info_panel.dart` [NEW]

Port from `ProxyInfoPanel.tsx`. Expandable card with 6 info tiles:

| Tile | Icon | Value |
|------|------|-------|
| Protocol | Globe | `SOCKS5` badge |
| Auth | Lock | `User/Pass ✓` or `None` |
| IP Address | Server | `1.2.3.4` (from geo) |
| Location | Pin | `City, Region, 🇺🇸 Country` |
| ISP/Org | Building | ISP name |
| Timezone | Clock | `America/New_York` |

Uses `ExpansionTile` with lazy-loading (geo fetch on first expand, same as extension's `expanded` state).

#### Files
- `mobile/lib/services/geo_service.dart` [NEW]
- `mobile/lib/models/geo_data.dart` [NEW]
- `mobile/lib/screens/home/widgets/connection_status_card.dart` [NEW]
- `mobile/lib/screens/home/widgets/proxy_info_panel.dart` [NEW]
- `mobile/lib/screens/home/home_screen.dart` [MODIFY]

#### Acceptance Criteria
- [ ] Geo lookup falls through 3 APIs on failure
- [ ] Country flag emoji renders correctly
- [ ] Connection card shows correct state based on `enabled` + `activeProxyId`
- [ ] Info panel lazy-loads geo on first expand
- [ ] Shimmer loading animation while geo fetching

---

### Phase 5 — Smart Rotation Engine

**Covers:** F12 (round-robin), F13 (random), F14 (weighted), F15 (sticky), F16 (time trigger), F17 (request trigger), F20 (skip failed), F21 (cooldown), F22 (retry count)

**Goal:** Port `rotationEngine.ts` to Dart. Replace `chrome.alarms` with Dart timers and `workmanager`.

#### How Rotation Works on Android

**Extension:** `chrome.alarms.create(name, { periodInMinutes })` fires an alarm → `rotateProxy()` runs in the service worker → `pickNext()` selects next proxy → `applyProxy()` updates `chrome.proxy.settings`.

**Android:** `Timer.periodic(Duration(minutes: interval))` fires in foreground → `pickNext()` selects next proxy → update `settingsProvider.activeProxyId` → if VPN is active, restart tunnel with new proxy.

```dart
class RotationNotifier extends Notifier<void> {
  Timer? _timer;

  void scheduleRotation(int intervalMinutes) {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => rotateProxy(),
    );
  }

  void cancelRotation() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> rotateProxy() async {
    final settings = ref.read(settingsProvider);
    if (!settings.enabled || settings.proxies.isEmpty) return;

    final next = pickNext(settings);
    if (next == null || next.id == settings.activeProxyId) return;

    // Stamp lastUsed on the proxy being rotated away from
    ref.read(settingsProvider.notifier).update(
      activeProxyId: next.id,
      proxies: settings.proxies.map((p) =>
        p.id == settings.activeProxyId ? p.copyWith(lastUsed: DateTime.now().millisecondsSinceEpoch) : p
      ).toList(),
    );
  }
}
```

---

**`pickNext()` function** — Direct port from `rotationEngine.ts` lines 23-87:

```dart
ProxyEntry? pickNext(AppSettings settings) {
  final proxies = settings.proxies;
  final activeProxyId = settings.activeProxyId;
  final rotation = settings.rotation;
  final autoDetect = settings.autoDetect;

  if (proxies.isEmpty) return null;

  // Filter pool (same logic as extension)
  var pool = proxies.where((p) {
    if (!autoDetect.autoSkipFlagged) return true;
    final s = p.testResult?.status;
    if (s == null || s == ProxyTestStatus.untested || s == ProxyTestStatus.ok) return true;
    if (s == ProxyTestStatus.dead || s == ProxyTestStatus.blocked) return false;
    return !rotation.skipFailed;
  }).toList();

  // Cooldown (same logic — only apply if it leaves alternatives)
  if (rotation.cooldownMinutes > 0) {
    final cutoff = DateTime.now().millisecondsSinceEpoch - rotation.cooldownMinutes * 60000;
    final cooled = pool.where((p) => p.lastUsed == null || p.lastUsed! < cutoff).toList();
    if (cooled.any((p) => p.id != activeProxyId)) pool = cooled;
  }

  if (pool.isEmpty) pool = proxies;

  final current = pool.indexWhere((p) => p.id == activeProxyId);

  switch (rotation.mode) {
    case RotationMode.roundRobin:
      return pool[(current + 1) % pool.length];

    case RotationMode.random:
      final candidates = pool.where((p) => p.id != activeProxyId).toList();
      final src = candidates.isNotEmpty ? candidates : pool;
      return src[Random().nextInt(src.length)];

    case RotationMode.weighted:
      final totalWeight = pool.fold<int>(0, (s, p) => s + (p.weight ?? 1));
      var r = Random().nextDouble() * totalWeight;
      for (final p in pool) {
        r -= (p.weight ?? 1);
        if (r <= 0) return p;
      }
      return pool.first;

    case RotationMode.sticky:
      final currentProxy = proxies.where((p) => p.id == activeProxyId).firstOrNull;
      if (currentProxy?.lastUsed != null) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - currentProxy!.lastUsed!;
        if (elapsed < rotation.stickySessionMinutes * 60000) return currentProxy;
      }
      return pool.first;
  }
}
```

---

**Background rotation** — For when the app is minimized:

```dart
// In main.dart
Workmanager().initialize(callbackDispatcher);
Workmanager().registerPeriodicTask(
  'proxy-rotation', 'rotateProxy',
  frequency: Duration(minutes: settings.rotation.intervalMinutes),
  constraints: Constraints(networkType: NetworkType.connected),
);

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'rotateProxy') {
      // Load settings from shared_preferences, run pickNext, save back
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(storageKey);
      if (json == null) return true;
      final settings = AppSettings.fromJson(jsonDecode(json));
      final next = pickNext(settings);
      if (next != null && next.id != settings.activeProxyId) {
        final updated = settings.copyWith(activeProxyId: next.id);
        await prefs.setString(storageKey, jsonEncode(updated.toJson()));
        // Optionally: show notification about rotation
      }
    }
    return true;
  });
}
```

**Android caveat:** `workmanager` uses Android's `WorkManager` under the hood. Minimum period is 15 minutes (Android OS limit). For intervals < 15 min, rely on foreground `Timer.periodic()` only.

**Chrome API replacement:**

| Extension | Android |
|-----------|---------|
| `chrome.alarms.create(name, { periodInMinutes })` | `Timer.periodic()` (foreground) + `Workmanager.registerPeriodicTask()` (background) |
| `chrome.alarms.clear(name)` | `timer.cancel()` + `Workmanager.cancelByUniqueName()` |
| `chrome.alarms.onAlarm.addListener` | Timer callback / Workmanager `executeTask` |

---

**Rotation settings UI** — `mobile/lib/screens/settings/widgets/rotation_settings.dart` [NEW]

Port from `SmartRotation.tsx`:

- **Mode selector:** 4 `ChoiceChip` widgets (Round Robin / Random / Weighted / Sticky)
- **Trigger selector:** 2 `ChoiceChip` widgets (Time interval / X requests) — skip tab-change and browser-restart (mobile N/A)
- **Interval input:** `TextField` with number keyboard + suffix text ("min" or "req")
- **Sticky session input:** Only shown when mode = sticky
- **Skip failed toggle:** `SwitchListTile`
- **Retry count:** `TextField` with number keyboard
- **Cooldown:** `TextField` with number keyboard + "min" suffix

#### New Packages

```yaml
dependencies:
  workmanager: ^0.5.0  # background periodic tasks
```

#### AndroidManifest.xml Changes

```xml
<!-- Already should have INTERNET, add: -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

#### Files
- `mobile/lib/providers/rotation_provider.dart` [NEW]
- `mobile/lib/screens/settings/widgets/rotation_settings.dart` [NEW]
- `mobile/lib/screens/settings/settings_screen.dart` [MODIFY]
- `mobile/lib/screens/home/home_screen.dart` [MODIFY] — "Rotate Now" button
- `mobile/lib/main.dart` [MODIFY] — workmanager init

#### Acceptance Criteria
- [ ] Round-robin cycles 1→2→3→1
- [ ] Random never picks current (when alternatives exist)
- [ ] Weighted picks higher-weight proxies more often
- [ ] Sticky stays on current within session window
- [ ] Dead proxies skipped when `skipFailed` enabled
- [ ] Cooldown prevents immediate reuse
- [ ] "Rotate Now" button rotates immediately
- [ ] Background rotation fires (with 15-min minimum)

---

### Phase 6 — Auto-Detection System

**Covers:** F33 (auto-detect scan), F34 (auto-remove dead), F35 (auto-skip flagged), F36 (slow threshold)

**Goal:** Port `AutoDetect.tsx` config and the scan-all-proxies workflow.

#### How Auto-Detect Works on Android

Same as extension: run `testProxy()` on every proxy → map results to flags → apply auto-actions.

```dart
class AutoDetectNotifier extends Notifier<bool> {
  // state = isRunning

  @override
  bool build() => false;

  Future<void> scanAll() async {
    state = true; // running
    final settings = ref.read(settingsProvider);
    final testService = ProxyTestService();

    final results = await testService.testAll(settings.proxies);

    var updatedProxies = settings.proxies.map((p) {
      final result = results[p.id];
      return result != null ? p.copyWith(testResult: result) : p;
    }).toList();

    // Auto-remove dead
    if (settings.autoDetect.autoRemoveDead) {
      updatedProxies = updatedProxies.where((p) =>
        p.testResult?.status != ProxyTestStatus.dead
      ).toList();
    }

    ref.read(settingsProvider.notifier).update(proxies: updatedProxies);
    state = false; // done
  }
}
```

**Auto-skip flagged** happens in `pickNext()` (Phase 5) — it reads `autoDetect.autoSkipFlagged` and filters the pool. No extra work needed here.

---

**Auto-detect settings UI** — `mobile/lib/screens/settings/widgets/auto_detect_settings.dart` [NEW]

Port from `AutoDetect.tsx`. Collapsible section with:

| Toggle | Description | Extension field |
|--------|-------------|----------------|
| Dead Proxies | Connection refused / timeout | `deadProxy` |
| Slow Proxies | Latency > threshold | `slowProxy` |
| Captcha-Heavy | Proxy triggers captcha | `captchaProxy` |
| Blocked Proxies | Returns 403 / access-denied | `blockedProxy` |
| Expired Credentials | 407 auth errors | `expiredCredentials` |
| Auto-remove Dead | Delete dead proxies | `autoRemoveDead` |
| Auto-skip Flagged | Skip bad proxies in rotation | `autoSkipFlagged` |

Each is a `SwitchListTile` with an icon, label, and description — same as the extension's `Row` component.

**Slow threshold slider:**

```dart
Slider(
  min: 500, max: 30000,
  divisions: 59,
  value: config.slowThresholdMs.toDouble(),
  label: '${config.slowThresholdMs}ms',
  onChanged: (v) => onChange(slowThresholdMs: v.round()),
)
```

**"Scan Now" button** — `ElevatedButton` that calls `ref.read(autoDetectProvider.notifier).scanAll()`. Shows `CircularProgressIndicator` while running.

#### Files
- `mobile/lib/providers/auto_detect_provider.dart` [NEW]
- `mobile/lib/screens/settings/widgets/auto_detect_settings.dart` [NEW]
- `mobile/lib/screens/settings/settings_screen.dart` [MODIFY]

#### Acceptance Criteria
- [ ] Scan Now tests all proxies and flags appropriately
- [ ] Auto-remove dead removes dead proxies from list
- [ ] Slow threshold is configurable (500ms–30000ms)
- [ ] All toggles are disabled when auto-detect master toggle is off
- [ ] Scan shows progress and prevents double-scan

---

### Phase 7 — Bypass Rules

**Covers:** F40 (hostname), F41 (wildcard), F42 (IP), F43 (CIDR), F44 (`<local>`)

**Goal:** Port `BypassForm.tsx` + `BypassList.tsx` + `validationService.ts`.

#### How Bypass Rules Work on Android

**Extension:** Bypass list feeds into `chrome.proxy.settings.set({ rules: { bypassList } })`.

**Android (dashboard mode):** Rules are stored and displayed. They don't actively bypass anything until VPN is implemented. When VPN is added (future), bypass rules map to `VpnService.Builder.addDisallowedApplication()` or tunnel route exclusions.

**Android (VPN mode — future):** The tun2socks config supports excluding specific IPs/domains from the tunnel. Bypass rules become tunnel exclusion rules.

For now: store, validate, display. Same UX as extension.

---

**Bypass rules screen** — `mobile/lib/screens/bypass/bypass_rules_screen.dart` [NEW]

Two sections on one screen:

**Add section** (from `BypassForm.tsx`):
- `TextField` with placeholder: `example.com or *.example.com or 192.168.1.0/24 or <local>`
- On submit: `validateBypassRule()` → `detectBypassType()` → add to settings
- Error text shown below on validation failure
- Format hint expandable (same 5 examples as extension)

**List section** (from `BypassList.tsx`):
- `ListView.builder` with each rule showing:
  - Rule pattern (monospace)
  - Type badge `Chip` (HOSTNAME / WILDCARD / IP / CIDR / LOCAL)
  - Delete button
- "Clear All" in app bar
- Empty state: "Add a rule above to get started"

---

**Route registration:**

```dart
// main.dart
GoRoute(path: 'bypass', builder: (c, s) => const BypassRulesScreen()),
```

#### Files
- `mobile/lib/screens/bypass/bypass_rules_screen.dart` [NEW]
- `mobile/lib/main.dart` [MODIFY] — add route

#### Acceptance Criteria
- [ ] Can add hostname, wildcard, IP, CIDR, `<local>` rules
- [ ] Invalid rules show error (spaces, bad wildcards, bad CIDR)
- [ ] Type auto-detected and displayed as colored badge
- [ ] Can remove individual rules
- [ ] "Clear All" removes all bypass rules

---

### Phase 8 — Theme System & UI Polish

**Covers:** F45 (light/dark toggle), F03–F04 (file import), F48 (proxy weight), F49 (saving indicator), F50 (error banner)

**Goal:** Dual theme, file picker import, weight editing, and UI polish.

#### Theme System

The extension uses CSS custom properties (`popup.css` lines 1-95). On Android, use Flutter's `ThemeData`:

```dart
// Light theme — mapped from extension's :root CSS vars
final lightTheme = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: Color(0xFF2563EB),      // --accent
    surface: Color(0xFFFFFFFF),      // --surface
    error: Color(0xFFDC2626),        // --danger
  ),
  scaffoldBackgroundColor: Color(0xFFF0F2F5),  // --bg
  useMaterial3: true,
);

// Dark theme — mapped from extension's [data-theme="dark"] CSS vars
final darkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: Color(0xFF3B82F6),      // --accent (dark)
    surface: Color(0xFF161B22),      // --surface (dark)
    error: Color(0xFFEF4444),        // --danger (dark)
  ),
  scaffoldBackgroundColor: Color(0xFF0D1117),  // --bg (dark)
  useMaterial3: true,
);
```

Theme toggle:

```dart
// In settingsProvider
void toggleTheme() {
  update(theme: state.theme == 'light' ? 'dark' : 'light');
}

// In main.dart
final themeProvider = Provider<ThemeMode>((ref) {
  final theme = ref.watch(settingsProvider).theme;
  return theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
});

// MaterialApp.router
themeMode: ref.watch(themeProvider),
theme: lightTheme,
darkTheme: darkTheme,
```

---

#### File Import

Extension uses `FileReader.readAsText()` + drag-drop in `ProxyForm.tsx`. On Android:

```dart
// In ImportScreen
Future<void> _pickFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['txt', 'csv', 'list', 'conf'],
  );
  if (result?.files.single.path != null) {
    final text = await File(result!.files.single.path!).readAsString();
    setState(() { bulkText = text; });
  }
}
```

---

#### Proxy Weight Editing

Extension defines `weight?: number` (1-10) on `ProxyEntry` but doesn't have a UI for editing it (only displayed in weighted rotation hint). Add a simple slider in the proxy detail/edit flow:

```dart
Slider(
  min: 1, max: 10,
  divisions: 9,
  value: proxy.weight?.toDouble() ?? 1,
  label: '${proxy.weight ?? 1}',
  onChanged: (v) => updateProxyWeight(proxy.id, v.round()),
)
```

---

#### Saving Indicator

Extension shows a "Saving" pill in the header. On Android:

```dart
// In ShellScreen — listen to savingStateProvider
if (ref.watch(savingStateProvider)) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Row(children: [
      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      SizedBox(width: 12),
      Text('Saving...'),
    ])),
  );
}
```

---

#### Error Banner

Extension shows a red error bar at top of popup. On Android:

```dart
// In ShellScreen
final error = ref.watch(saveErrorProvider);
if (error != null) {
  return MaterialBanner(
    content: Text(error),
    backgroundColor: Theme.of(context).colorScheme.errorContainer,
    actions: [
      TextButton(onPressed: () => ref.read(saveErrorProvider.notifier).state = null, child: Text('Dismiss')),
    ],
  );
}
```

#### New Packages

```yaml
dependencies:
  file_picker: ^8.0.0  # file import
```

#### Files
- `mobile/lib/main.dart` [MODIFY] — dual theme
- `mobile/lib/screens/settings/settings_screen.dart` [MODIFY] — theme toggle, weight slider
- `mobile/lib/screens/proxies/import_screen.dart` [MODIFY] — file picker
- `mobile/lib/screens/shell_screen.dart` [MODIFY] — saving indicator, error banner

#### Acceptance Criteria
- [ ] Theme toggles between light and dark
- [ ] Theme persists across restarts
- [ ] File picker opens .txt/.csv/.list/.conf files
- [ ] Imported text feeds into bulk parser
- [ ] Proxy weight slider works (1-10)
- [ ] Saving indicator shows during API calls
- [ ] Error banner shows on save failure, dismissible

---

### Phase 9 — VPN-Based Proxy Application (Advanced)

**Covers:** F09 (apply proxy system-wide), F10 (clear proxy / direct connection)

**Goal:** Actually route all Android device traffic through the selected proxy using VpnService + tun2socks.

> ⚠️ This is the most complex phase. It requires native Android code (Kotlin), VPN permissions, and a foreground service. **Defer until all dashboard features are solid.**

#### How System-Wide Proxy Works on Android

Regular Android apps **cannot** set a system proxy. The only way is to create a VPN tunnel:

1. App calls `VpnService.prepare()` → Android shows a system dialog: "Allow ProxyM to set up a VPN connection?"
2. User approves → app creates a TUN interface via `VpnService.Builder`
3. All device traffic routes through the TUN interface
4. App runs `tun2socks` to forward TUN traffic through the proxy (SOCKS5, HTTP CONNECT, etc.)
5. To disconnect: stop the VPN service

```
[All device traffic] → [TUN interface] → [tun2socks] → [Proxy server] → [Internet]
```

#### Implementation Approach

**Option A: `leaf` library** — Rust-based proxy tool, supports SOCKS5/HTTP, runs as a native binary. Communicate via stdin/stdout from Dart.

**Option B: `tun2socks` (Go)** — Mature, widely used. Compile as a shared library, call via FFI or platform channel.

**Option C: Flutter plugin** — Use existing plugins like `flutter_v2ray` or write a thin Kotlin wrapper around Android's `VpnService`.

**Recommended: Option C** — Write a platform channel:

```kotlin
// android/app/src/main/kotlin/.../VpnProxyService.kt
class VpnProxyService : VpnService() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val host = intent?.getStringExtra("proxy_host") ?: return START_NOT_STICKY
        val port = intent.getIntExtra("proxy_port", 0)
        val protocol = intent.getStringExtra("proxy_protocol") ?: "socks5"

        val builder = Builder()
            .addAddress("10.0.0.2", 24)
            .addRoute("0.0.0.0", 0) // route all traffic
            .addDnsServer("8.8.8.8")
            .setSession("ProxyM - $host:$port")

        // Apply bypass rules
        bypassRules.forEach { rule ->
            builder.addDisallowedApplication(rule) // for per-app bypass
            // or exclude IP ranges from routing
        }

        val vpnInterface = builder.establish()
        // Start tun2socks with vpnInterface file descriptor
        startTun2Socks(vpnInterface, host, port, protocol, username, password)

        return START_STICKY
    }
}
```

```dart
// Dart side
class VpnProxyEngine {
  static const _channel = MethodChannel('com.proxym/vpn');

  static Future<void> applyProxy(ProxyEntry proxy, List<BypassRule> bypass) async {
    await _channel.invokeMethod('startVpn', {
      'host': proxy.host,
      'port': proxy.port,
      'protocol': proxy.protocol.name,
      'username': proxy.username,
      'password': proxy.password,
      'bypassRules': bypass.map((r) => r.pattern).toList(),
    });
  }

  static Future<void> clearProxy() async {
    await _channel.invokeMethod('stopVpn');
  }
}
```

#### AndroidManifest.xml Changes

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />

<service
    android:name=".VpnProxyService"
    android:permission="android.permission.BIND_VPN_SERVICE"
    android:foregroundServiceType="specialUse">
    <intent-filter>
        <action android:name="android.net.VpnService" />
    </intent-filter>
</service>
```

#### How Bypass Rules Apply with VPN

| Bypass Type | VPN Implementation |
|-------------|-------------------|
| hostname (`example.com`) | Add to tun2socks bypass config |
| wildcard (`*.example.com`) | Add to tun2socks bypass config |
| IP (`192.168.1.1`) | `VpnService.Builder.addRoute()` excludes specific IPs |
| CIDR (`192.168.0.0/24`) | `VpnService.Builder.addRoute()` excludes IP range |
| `<local>` | Exclude `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` |

#### How Auth Handler Maps

| Extension (`authHandler.ts`) | Android VPN |
|------------------------------|-------------|
| `webRequest.onAuthRequired` listener | tun2socks handles SOCKS auth natively |
| Cache active proxy credentials | Pass credentials to tun2socks on tunnel start |
| `storage.onChanged` to update cache | Restart tunnel on proxy change with new credentials |

#### Files
- `mobile/android/app/src/main/kotlin/.../VpnProxyService.kt` [NEW]
- `mobile/lib/services/vpn_proxy_engine.dart` [NEW]
- `mobile/lib/screens/home/home_screen.dart` [MODIFY] — connect/disconnect buttons

#### Acceptance Criteria
- [ ] VPN permission dialog shows and user can approve
- [ ] All device traffic routes through selected proxy
- [ ] SOCKS5 + HTTP proxy types work
- [ ] Proxy auth (username/password) works
- [ ] Bypass rules exclude specified hosts/IPs
- [ ] Disconnect returns to direct connection
- [ ] Foreground notification shows while VPN is active
- [ ] Rotation triggers VPN tunnel restart with new proxy

---

## 11. Feature-to-Phase Matrix

| Feature | Phase | How It Works on Android |
|---------|-------|------------------------|
| F01 URI add | P1+P2 | `parseProxyUri()` in Dart → same 4-format auto-detect |
| F02 Manual add | P2 | Form fields → `ProxyEntry` constructor |
| F03 Bulk import (text) | P1+P2 | `parseBulkProxies()` in Dart → same line-by-line parser |
| F04 Bulk import (file) | P8 | `file_picker` package → read text → bulk parser |
| F05 Proxy list | P2 | `ListView.builder` with protocol badges |
| F06 Set active | P2 | Tap → `settingsProvider.update(activeProxyId: id)` |
| F07 Remove proxy | P2 | Swipe-to-delete or icon button |
| F08 Clear all | P2 | AppBar action → confirm dialog → clear |
| F09 Apply proxy (system) | P9 | `VpnService` + `tun2socks` |
| F10 Clear proxy | P9 | Stop VPN service |
| F11 Proxy auth (407) | P3+P9 | `HttpClient.addProxyCredentials()` for tests; tun2socks for VPN |
| F12 Round-robin | P5 | `pool[(current + 1) % pool.length]` |
| F13 Random | P5 | `Random().nextInt()` excluding current |
| F14 Weighted | P5 | Cumulative weight random selection |
| F15 Sticky | P5 | Check `lastUsed` against `stickySessionMinutes` |
| F16 Time trigger | P5 | `Timer.periodic()` + `workmanager` |
| F17 Request trigger | P5 | Counter in provider, rotate at threshold |
| F18 Tab-change trigger | — | N/A on mobile (no browser tabs) |
| F19 Browser-restart trigger | — | N/A (use app lifecycle instead) |
| F20 Skip failed | P5 | Pool filter in `pickNext()` |
| F21 Cooldown | P5 | `lastUsed` timestamp comparison |
| F22 Retry count | P5 | Config field, retry loop on connect failure |
| F23 Test single | P3 | `HttpClient` with `findProxy` → test URLs |
| F24 Test all | P3 | `Pool(5)` concurrent limit → test each |
| F25 Latency | P3 | `Stopwatch` around HTTP request |
| F26 Download speed | P3 | `speed.cloudflare.com/__down?bytes=100000` → bytes/sec |
| F27 DNS latency | P3 | `dns.google/resolve` → `Stopwatch` |
| F28 SSL | P3 | Check `res.statusCode == 200` on HTTPS endpoint |
| F29 Captcha detect | P3 | Scan response body for signature strings |
| F30 Blocked detect | P3 | Scan response body for blocked signatures |
| F31 DNS leak | P3 | Compare resolved IP to proxy host |
| F32 Expired creds | P3 | Check for HTTP 407 status |
| F33 Auto-detect scan | P6 | `testAll()` → apply flags → auto-actions |
| F34 Auto-remove dead | P6 | Filter `status != dead` after scan |
| F35 Auto-skip flagged | P5+P6 | `pickNext()` reads `autoSkipFlagged` flag |
| F36 Slow threshold | P6 | Config slider, used in `deriveStatus()` |
| F37 Geo lookup | P4 | `Dio.get('https://ipwho.is/$host')` with 3 fallbacks |
| F38 Country flag | P1+P4 | `String.fromCharCodes()` codepoint math |
| F39 Connection state | P4 | `getConnectionState()` → 3-state card |
| F40–F44 Bypass rules | P7 | `validateBypassRule()` + `detectBypassType()` in Dart |
| F45 Theme toggle | P8 | `ThemeMode.light/dark` + `shared_preferences` |
| F46 Enable/disable | P2 | `settingsProvider.update(enabled: bool)` |
| F47 Rotation interval | P2+P5 | Number input → `settingsProvider` → restart timer |
| F48 Proxy weight | P8 | Slider 1–10 on proxy edit |
| F49 Saving indicator | P2+P8 | `SnackBar` with progress spinner |
| F50 Error banner | P2+P8 | `MaterialBanner` with dismiss |

---

## 12. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **No system-wide proxy on mobile** | High | Phase 9 (VPN) solves this. MVP phases 1-8 are dashboard-only. |
| **Test engine routes through proxy** | Medium | Use `HttpClient.findProxy` to explicitly route test traffic through the proxy being tested. Without this, tests would go direct. |
| **Background task reliability** | Medium | Android kills background tasks aggressively. `workmanager` minimum period is 15 min. For <15 min rotation, rely on foreground timer only. |
| **Geo API rate limiting** | Low | 3-fallback chain + cache results per proxy host. |
| **Backend API parity** | Medium | Backend may not have endpoints for rotation config, auto-detect config, bypass rules. Add Laravel migrations + API routes. |
| **Offline behavior** | Medium | Extension is fully offline. Mobile caches `AppSettings` in `shared_preferences` for offline access. Sync on reconnect. |
| **VPN permission rejection** | Medium | User may deny VPN permission. App must work fully in dashboard mode without VPN. |
| **tun2socks binary size** | Low | Adds ~5-10MB to APK. Use split APKs per architecture. |
| **Google Play VPN policy** | Medium | Google Play requires VPN apps to declare VPN usage and comply with their policy. Must submit a VPN app questionnaire. |

---

## 13. Edge Cases

| Edge Case | Extension Handling | Android Handling |
|-----------|-------------------|-----------------| 
| IPv6 proxy `[::1]:port` | `splitHostPort()` handles brackets | Same parser logic in Dart |
| URL-encoded creds `%40` | `decodeURIComponent()` | `Uri.decodeComponent()` |
| Empty proxy list + rotation | `pickNext()` returns null | Same — no-op |
| All proxies failed + cooldown | Falls back to full pool | Same logic |
| Cooldown too strict | Relaxes if no alternatives | Same logic |
| Duplicate entries | Allowed (no dedup) | Consider dedup by `host:port` |
| Large lists (1000+) | In-memory | Paginate ListView, lazy-load from backend |
| Concurrent test-all | `Promise.all` (unbounded) | `Pool(5)` to limit concurrent sockets |
| File encoding | UTF-8 default | `File.readAsString()` defaults UTF-8 |
| Port 0 or 65536 | `parsePort()` rejects | Same validation |
| App killed during rotation | Alarm persists in Chrome | `workmanager` task re-registers on boot |
| VPN tunnel interrupted | N/A | Auto-reconnect in `VpnService.onRevoke()` |
| Split-screen / PiP | N/A | VPN stays active across window modes |

---

## 14. Future Improvements

1. **Per-app proxy rules** — Android split-tunneling via `VpnService.Builder.addDisallowedApplication()`
2. **Proxy speed history** — Chart latency over time per proxy (use `fl_chart`)
3. **Proxy expiry notifications** — Push via FCM when creds expire
4. **QR code import** — `mobile_scanner` package to scan proxy config
5. **Proxy sharing** — Deep links with encoded proxy config
6. **Home screen widget** — Show active proxy + latency (use `home_widget`)
7. **Favorites / Pinned** — Mark proxies for quick access
8. **Export proxies** — Share as .txt file via `share_plus`
9. **Scheduled rotation** — "Use proxy X between 9am-5pm"
10. **WireGuard support** — Additional tunnel protocol
11. **iOS VPN support** — `NetworkExtension` framework (NEPacketTunnelProvider)

---

## 15. Implementation Checklist

### Phase 1 — Data Models & Utils
- [ ] `models/proxy_entry.dart` — ProxyEntry, ProxyTestResult, ProxyFlags, enums
- [ ] `models/bypass_rule.dart` — BypassRule, BypassType
- [ ] `models/rotation_config.dart` — RotationConfig, RotationMode, RotationTrigger
- [ ] `models/auto_detect_config.dart` — AutoDetectConfig
- [ ] `models/app_settings.dart` — AppSettings composite + defaults
- [ ] `utils/proxy_parser.dart` — 4 parsers + auto-detect + bulk
- [ ] `utils/proxy_formatter.dart` — display + short format
- [ ] `utils/bypass_validator.dart` — validate + detect type
- [ ] `utils/country_flag.dart` — emoji flag from country code
- [ ] `utils/constants.dart` — protocol list, storage key
- [ ] Unit tests for all 4 proxy formats
- [ ] Unit tests for bulk parser (comments, blanks, errors)
- [ ] Unit tests for bypass validator

### Phase 2 — Settings & Proxy CRUD
- [ ] Upgrade `ProxyItem` → `ProxyEntry` in proxy_provider
- [ ] Create `settings_provider.dart` with local cache
- [ ] URI auto-detect input in `AddProxyScreen`
- [ ] Active proxy selection (tap in list)
- [ ] Protocol badge chips on proxy list items
- [ ] Auth status icon on proxy list items
- [ ] "Clear All" action
- [ ] Saving state indicator (SnackBar)
- [ ] Error banner (MaterialBanner)
- [ ] Enable/disable toggle on home screen
- [ ] Rotation interval input

### Phase 3 — Proxy Testing
- [ ] `proxy_test_service.dart` — full test with HttpClient.findProxy
- [ ] Connectivity + latency test (httpbin.org)
- [ ] Download speed test (speed.cloudflare.com)
- [ ] DNS latency test (dns.google)
- [ ] SSL validation check
- [ ] Captcha signature detection
- [ ] Blocked signature detection
- [ ] DNS leak detection
- [ ] Expired credentials (407) detection
- [ ] Test single proxy UI with 6 metric cards
- [ ] Test all proxies with progress bar + pool throttling

### Phase 4 — Geo & Connection
- [ ] `geo_service.dart` — 3-API fallback (ipwho.is, ip.guide, freeipapi.com)
- [ ] `geo_data.dart` model
- [ ] Connection status card (closed/waiting/connected)
- [ ] Proxy info panel (expandable, lazy geo fetch)
- [ ] Country flag emoji in info panel
- [ ] Shimmer loading state

### Phase 5 — Smart Rotation
- [ ] `rotation_provider.dart` — pickNext() with 4 modes
- [ ] Round-robin implementation
- [ ] Random (exclude current) implementation
- [ ] Weighted (cumulative random) implementation
- [ ] Sticky (session window) implementation
- [ ] Pool filtering (skip dead/blocked/slow)
- [ ] Cooldown enforcement
- [ ] Foreground Timer.periodic rotation
- [ ] Background workmanager rotation
- [ ] Rotation settings UI (mode chips, trigger, failure toggles)
- [ ] "Rotate Now" button on home screen
- [ ] workmanager init in main.dart

### Phase 6 — Auto-Detection
- [ ] `auto_detect_provider.dart` — scanAll + auto-actions
- [ ] Auto-detect settings UI (7 toggle rows)
- [ ] Slow threshold slider (500ms–30000ms)
- [ ] "Scan Now" button with progress
- [ ] Auto-remove dead on scan
- [ ] Auto-skip integration with rotation pool

### Phase 7 — Bypass Rules
- [ ] `bypass_rules_screen.dart` — add/list/remove
- [ ] Input validation with error messages
- [ ] Type auto-detection badges (5 types)
- [ ] Format hint section (expandable)
- [ ] Clear all bypass rules
- [ ] Route registration in GoRouter

### Phase 8 — Theme & Polish
- [ ] Light ThemeData (from extension CSS vars)
- [ ] Dark ThemeData (from extension dark CSS vars)
- [ ] Theme toggle in settings
- [ ] Theme persistence in shared_preferences
- [ ] File picker import (.txt, .csv, .list, .conf)
- [ ] Proxy weight slider (1-10)
- [ ] Protocol badge color system (HTTP/HTTPS/SOCKS4/SOCKS5)

### Phase 9 — VPN Proxy (Advanced)
- [ ] Kotlin VpnProxyService
- [ ] Platform channel (MethodChannel)
- [ ] tun2socks integration
- [ ] SOCKS5 proxy support
- [ ] HTTP proxy support
- [ ] Proxy authentication
- [ ] Bypass rules → VPN route exclusions
- [ ] Foreground notification
- [ ] Connect/disconnect UI
- [ ] Auto-reconnect on tunnel drop
- [ ] Rotation → tunnel restart
- [ ] AndroidManifest VPN permissionser.dart`
- [ ] Create `utils/proxy_formatter.dart`
- [ ] Create `utils/bypass_validator.dart`
- [ ] Create `utils/country_flag.dart`
- [ ] Create `utils/constants.dart`
- [ ] Unit tests for proxy parser (all 4 formats)
- [ ] Unit tests for bulk parser
- [ ] Unit tests for bypass validator

### Phase 2 — Provider Upgrade & Settings
- [ ] Upgrade `ProxyItem` → `ProxyEntry`
- [ ] Create `settings_provider.dart`
- [ ] Add URI auto-detect to `AddProxyScreen`
- [ ] Active proxy selection in `ProxyListScreen`
- [ ] Clear all proxies action
- [ ] Local settings cache with `shared_preferences`
- [ ] Backend migration for settings fields (if needed)

### Phase 3 — Testing & Geo
- [ ] Create `proxy_test_service.dart`
- [ ] Create `geo_service.dart`
- [ ] Enhance `ProxyTestScreen` with 6 metrics
- [ ] Enhance `BulkTestScreen` with progress
- [ ] Create `proxy_info_panel.dart` widget
- [ ] Create `connection_status_card.dart` widget
- [ ] Integrate info panel into `HomeScreen`

### Phase 4 — Smart Rotation
- [ ] Create `rotation_provider.dart`
- [ ] Implement round-robin, random, weighted, sticky
- [ ] Pool filtering (skip failed, cooldown)
- [ ] Timer-based rotation (foreground)
- [ ] `workmanager` rotation (background)
- [ ] Rotation settings UI
- [ ] "Rotate Now" button

### Phase 5 — Auto-Detect & Bypass
- [ ] Create `auto_detect_provider.dart`
- [ ] Auto-detect settings UI
- [ ] "Scan Now" with progress
- [ ] Auto-remove dead toggle
- [ ] Auto-skip flagged toggle
- [ ] Create `bypass_rules_screen.dart`
- [ ] Bypass rule add/remove
- [ ] Bypass type detection and badges

### Phase 6 — Theme & Polish
- [ ] Dual ThemeData (light + dark)
- [ ] Theme toggle + persistence
- [ ] Saving indicator
- [ ] Error banner
- [ ] Protocol badges
- [ ] Global enable/disable toggle
- [ ] File picker import
