# Workshop Manager — Batch Processing with Morning/Evening Shifts (PRD)

**Version:** 1.0  
**Status:** Draft (ready for implementation)  
**Owner:** Workshop Manager App Team  
**Last Updated:** 2025-08-13 (the device's local time zone, local offset)

---

## 1. Summary

This document specifies the requirements to extend the Workshop Manager **Batch Processing** feature with **Morning (早班) / Evening (晚班) shift scheduling** and **same‑day vs. next‑day planning rules**. The feature enforces a 12:00 local cutoff for same‑day planning, remains **color-only** for batch edits, checks that machines are running before batch creation, and **reuses** the existing production configuration approval flow.

> **Time Basis / 时间基准**
> All rules are evaluated in the **device's local time zone** (provided by the OS).
> 所有业务规则以**设备本地时间**为准（由操作系统提供的时区）。


---

## 2. Goals & Non‑Goals

### Goals
- Allow Workshop Managers to create batch plans for **today** and **tomorrow** with **morning/evening** shift selection.
- Enforce **cutoff logic** for same-day (evaluated in the **device's local time**):  
  - **Before 12:00** → both **morning** and **evening** shifts are available for **today**.  
  - **At/after 12:00** → **only evening** shift is available for **today**.  
  - **Tomorrow** → both shifts are always available.
- Keep batch editing **color‑only**; any product/model change must be done in Production Configuration.
- Block batch creation when **no machines are running**.
- Integrate with the **existing approval workflow** and audit logging.
- Maintain modular separation:  
  - **Batch Processing** → color planning per date/shift.  
  - **Equipment Management** → detailed machine status/monitoring.  
  - **Production Configuration** → product changes and complex setup.

### Non‑Goals
- Scheduling for dates **beyond today/tomorrow**.
- Modifying product/model or workstation topology from Batch Processing.
- Introducing a new approval system (we reuse the existing one).

---

## 3. Scope

- **In scope:** UI/UX for date & shift selection, color-only modification UI, policy enforcement, validations, service & model updates, telemetry, security & audits, accessibility, rollout controls.
- **Out of scope:** Overtime/holiday calendars, cross‑site coordination, multi‑time‑zone per user (single time zone is used: **the device's local time zone**).

---

## 4. Roles & Permissions (RBAC)

- **Workshop Manager**: Can create and submit color-only batches for allowed dates/shifts.  
- **Administrator**: Reviews/approves/rejects using existing approval flow.  
- **Others**: No access to create/submit batches.

Enforcement via `RBACService.has(role: .workshopManager)` at entry and submit points.

---

## 5. Definitions

- **Shift**:  
  - `morning` (早班)  
  - `evening` (晚班)
- **Cutoff**: Local **12:00** (the device's local time zone) defines availability for **today**.

---

## 6. Business Rules

### 6.1 Time Zone
- All calculations in **the device's local time zone (as provided by the OS)**. The app obtains the zone from configuration; default is the device's local time zone.

### 6.2 Allowed Shifts by Date/Time

| Target Date | Local Time Now         | Allowed Shifts       |
|-------------|------------------------|----------------------|
| Today       | **< 12:00**            | Morning, Evening     |
| Today       | **≥ 12:00**            | Evening only         |
| Tomorrow    | Any                    | Morning, Evening     |

*All evaluations are in the **device's local time** / 所有判断以**设备本地时间**为准。*

> Exactly **12:00:00** is treated as **after cutoff** (today → evening only).

### 6.3 Machine Running Check
- Batch creation is allowed **only** if at least **one machine is running** (`MachineProductionStatusService.isAnyMachineRunning() == true`).  
- If not, show blocking message:  
  - **CN:** “无法创建批次 - 当前无生产活动，请先启动机台”  
  - **EN:** “Cannot create batch — No active production. Start a machine first.”

### 6.4 Color‑Only Edits
- Only **color** fields may be changed within Batch Processing.  
- Attempting to change **product/model** leads to a blocking validation with guidance to **Production Configuration**.

### 6.5 Approval Flow
- Reuse existing **Production Configuration approval** pipeline.  
- Batches include `date` and `shift` metadata end‑to‑end.

---

## 7. User Stories

1. **As a Workshop Manager (11:30)**, I can create **today**’s **morning** and **evening** batches and submit for approval.  
2. **As a Workshop Manager (12:05)**, I can only create **today**’s **evening** batch; morning is disabled with a rationale.  
3. **As a Workshop Manager (any time)**, I can create **tomorrow**’s **morning** and **evening** batches.  
4. **As a Workshop Manager**, if **no machines** are running, I cannot create a batch and I see a clear message.  
5. **As a Workshop Manager**, I can only adjust **colors**; attempts to change product are blocked with a redirect prompt.  
6. **As an Administrator**, I review and approve batches as usual, with shift/date visible in the summary.

---

## 8. UX & UI Requirements

### 8.1 Entry Screen — Batch Creation
- Controls:
  - **Date Selector**: Segmented (Today / Tomorrow).  
  - **Shift Selector**: Chips/Segment (Morning / Evening). Disabled states reflect `allowedShifts(for: date)`.
- Default selections:
  - Today `< 12:00` → default **Morning**.  
  - Today `≥ 12:00` → default **Evening**.  
  - Tomorrow → default **Morning**.
- Disabled messaging (tooltip or inline helper):
  - CN: “已过 12:00，今日仅可创建晚班。”  
  - EN: “It’s after 12:00 — only the evening shift is available for today.”
- Color‑only editor:
  - **Quick mode**: Inline picker per row.  
  - **Advanced mode**: Bottom sheet with **current vs. proposed** side‑by‑side.
- Machine status:
  - Only a **running/not running** pre‑check within Batch. Detailed machine status remains in **Equipment Management**.

### 8.2 Summary & Submit
- Summary includes: date, shift, machines included, current vs. proposed colors, validation warnings (if any).
- Submit button triggers standard approval flow.

### 8.3 Accessibility
- Dynamic Type supported (no truncation).  
- VoiceOver labels for shift/date controls and color fields.  
- Color‑independent indicators (icons/text) for status.

---

## 9. Validation & Error Handling

- **Pre‑creation**:
  - Block when `allowedShifts` doesn’t include chosen shift → error `shiftNotAllowed`.
  - Block when no machines are running → `noRunningMachines` (message above).
- **Pre‑submit**:
  - **Color‑only** validation → block any product/model changes (`productChangeNotAllowed`).
  - **Color conflict** via `WorkstationCapacityService` → show actionable message and proposed fixes.
- **Crossing the cutoff mid‑edit**:
  - If the user has the screen open and time passes ≥ 12:00, allow draft to remain, but **re‑validate on submit**, blocking or forcing shift change if needed.

---

## 10. Security & Audit

- RBAC at entry and submit points; unauthorized users cannot create/submit.  
- Session checks: user identity, expiry, nonce.  
- Audit events (via `NewAuditingService`):
  - `batch_v2.create_attempt` (fields: userId, date, shift, allowedShifts, machineCount)  
  - `batch_v2.color_change` (before/after)  
  - `batch_v2.submit` (userId, date, shift, batchId)  
  - `batch_v2.create_blocked_no_machine`

---

## 11. Data Model Changes

```swift
// Domain/Shared/Shift.swift
enum Shift: String, Codable, CaseIterable { case morning, evening }

// Domain/Batch/ProductionBatch.swift
struct ProductionBatch: Codable {
    var id: String
    var date: Date
    var shift: Shift             // NEW
    // ...existing fields
}

// Domain/Batch/BatchColorModification.swift
struct BatchColorModification: Codable {
    var machineId: String
    var workstationId: String
    var currentColorId: String
    var proposedColorId: String
    var shift: Shift             // NEW
}
```

**Migration:** legacy records without `shift` default to `evening` and are marked `legacy_default` in audit when first touched.

---

## 12. Services & APIs

```swift
// Infrastructure/Time/TimeProvider.swift
protocol TimeProvider { var now: Date { get } var timeZone: TimeZone { get } }
struct SystemTimeProvider: TimeProvider {
    var now: Date { Date() }
    var timeZone: TimeZone { TimeZone(identifier: "the device's local time zone") ?? .current }
}

// Domain/Planning/DateShiftPolicy.swift
struct DateShiftPolicy {
    func allowedShifts(for targetDate: Date) -> Set<Shift>
}

// Domain/Batch/ProductionBatchService.swift
protocol ProductionBatchService {
    func allowedShifts(for date: Date) -> Set<Shift> // proxies DateShiftPolicy
    func createColorBatch(for date: Date, shift: Shift) async throws -> ProductionBatch
    func validateColorOnly(mods: [BatchColorModification]) throws
}
```

**Errors:**  
`shiftNotAllowed`, `noRunningMachines`, `productChangeNotAllowed`, `colorConflict`.

---

## 13. Telemetry & Observability

- Metrics: creation attempts, blocks by reason, submit success/failure, color conflict ratio, approval turnaround.  
- Logs tagged `batch_v2.*` with `date`, `shift`, `userId`.  
- Crash breadcrumbs per new screens.

---

## 14. Performance

- Cache machine running state for up to **30 seconds** to reduce polling.  
- 95th percentile **first render < 400ms**.

---

## 15. Configuration & Feature Flags

- `FeatureFlags.simplifiedBatchV2 = true` (toggle for rollout/rollback).  
- `BatchConfig.cutoffHour = 12` (soft config for future changes).  
- Time zone configurable; default **the device's local time zone**.

---

## 16. Rollout & Rollback

- **Gradual rollout** to Workshop Manager role subset.  
- Monitor: `create_blocked_no_machine`, `shiftNotAllowed`, submit failure rate, crash rate.  
- **Rollback** by flipping `FeatureFlags.simplifiedBatchV2` to `false`.

---

## 17. Acceptance Criteria (AC)

1. **Cutoff Logic**:  
   - Today `< 12:00`: both shifts selectable; `default = morning`.  
   - Today `≥ 12:00`: only evening selectable; `default = evening`.  
   - Tomorrow: both shifts selectable; `default = morning`.

2. **Machine Check**:  
   - If no running machines: batch creation is blocked with the specified message.

3. **Color‑Only**:  
   - Product/model edits are blocked with guidance to Production Configuration.

4. **Approval Reuse**:  
   - Submissions follow the existing approval flow and surface `date/shift` in summaries.

5. **Accessibility**:  
   - Controls are accessible via VoiceOver; dynamic type does not truncate important labels.

6. **Audit & Security**:  
   - All changes/events are logged with user identity; unauthorized roles cannot create/submit.

---

## 18. Test Plan (Key Cases)

- **Policy**: 11:59 vs 12:00 vs 12:01 (today), and tomorrow any time — all in the **device's local time**.  
- **Machine**: running vs not running.  
- **Validation**: product change attempt blocked; color conflict messaging.  
- **Cross‑cutoff**: user starts before 12:00, submits after → blocked/re‑select as per rules.  
- **i18n**: CN/EN strings display correctly.  
- **A11y**: ScreenReader traversal, dynamic type XL/AX5.

---

## 19. i18n Strings

```json
{
  "batch.shift.morning": "早班",
  "batch.shift.evening": "晚班",
  "batch.shift.today": "今日",
  "batch.shift.tomorrow": "次日",
  "batch.shift.disabledAfterNoon.cn": "已过 12:00，今日仅可创建晚班。",
  "batch.shift.disabledAfterNoon.en": "It’s after 12:00 — only the evening shift is available for today.",
  "batch.create.noMachines.cn": "无法创建批次 - 当前无生产活动，请先启动机台",
  "batch.create.noMachines.en": "Cannot create batch — No active production. Start a machine first.",
  "batch.error.productChange.cn": "产品修改需前往“生产配置”进行。",
  "batch.error.productChange.en": "Product changes must be performed in Production Configuration."
}
```

---

## 20. Open Questions (if any)

- None for v1.0. Future: holiday calendars, per‑site time zones, overtime shifts.

---

*End of document.*
