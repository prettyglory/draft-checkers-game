# Technical risk register

| Risk | Likelihood / impact | Mitigation and proof |
| --- | --- | --- |
| Cross-platform nearby Bluetooth is not one uniform API | High / High | Capability-gated adapters; prefer reliable LAN/Bonjour; native Android Bluetooth and Apple Network framework paths; maintain a real-device matrix |
| Apple nearby APIs evolve or deprecate | High / High | Use Network framework/Bonjour abstraction; avoid a hard dependency on deprecated Multipeer Connectivity; isolate native code behind `GameTransport` |
| LAN permissions and discovery differ by OS/version | High / Medium | Permission rationale/denial UX, room-code/IP fallback, Android version tests, iOS local-network declarations, foreground lifecycle recovery |
| Client/server rules drift enables cheating or false rejects | Medium / Critical | Reuse the pure-Dart engine on both sides, pin protocol/engine versions, run shared conformance vectors in both targets |
| Concurrent or replayed commands corrupt a match | Medium / Critical | Single match authority, unique command IDs, monotonically sequenced events, database constraints, idempotent responses |
| Reconnect produces divergent boards | Medium / Critical | Acked event sequence plus canonical state hash; event replay; authoritative snapshot replacement on gaps/hash mismatch |
| Device clocks can be manipulated | High / High | Authority owns time; clients display estimates only; signed-in online clients cannot submit elapsed time or timeout results |
| AI freezes the UI or drains battery | Medium / High | Isolate execution, iterative deepening, cancellation, time/node budgets, difficulty-specific resource ceilings, profiling on low-end devices |
| Flying-king multi-capture bugs | High / High | Path-based moves, delayed/immediate removal policies, exhaustive position fixtures, property/fuzz tests |
| Rule labels overpromise correctness | Medium / High | Source-linked rule specs, expert review, conformance corpus, variant/version shown in match metadata |
| Offline progress is tampered with then synced | High / Medium | Server distinguishes trusted competitive data from local progress; validates unlock prerequisites; never imports client ratings/results |
| Rating farming/collusion | Medium / High | Transactional rating updates, opponent/repetition signals, rate limits, anomaly review, season policies, reversible audit events |
| Backend instance loss interrupts live matches | Medium / High | Redis lease/presence, durable ordered events, frequent snapshots, ownership handoff, reconnect grace window, chaos tests |
| Schema/protocol evolution breaks old clients or saves | Medium / High | Versioned DTOs/saves, forward migrations, compatibility window, minimum-client policy only when unavoidable |
| Scope and content volume delay a stable core | High / High | Enforce phase gates; finish one fully tested ruleset and game loop before expanding content or online surfaces |

## Bluetooth product decision

"Bluetooth multiplayer" is presented only when the device/OS adapter is tested
and supported. It must not be a fake cross-platform toggle. LAN nearby play is
the primary offline direct-connect path; Bluetooth is an additional transport,
not a separate game implementation.

## Security boundaries

- The online server validates actor, turn, legal path, clock, room membership,
  match lifecycle, result, rating, rewards, and rate limits.
- Secrets live in server configuration or platform secure storage, never Dart
  source, bundled assets, logs, or ordinary preferences.
- Network payloads are size-limited, schema-validated, authenticated, sequenced,
  and safe to repeat.
- Logs avoid access tokens, private profile fields, precise nearby identifiers,
  and raw invitation secrets.

