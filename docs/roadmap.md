# Development roadmap

Every phase ends with updated documentation, formatting/static analysis, tests,
manual acceptance of the changed flow, and a meaningful commit.

Phases 1-4 are complete. Phase 5 remains in progress. Phase 6 now has legal
beginner selection, weighted evaluation, fixed/iterative alpha-beta, and
tactical ordering, history-safe transpositions, bounded quiescence, and
aspiration-window iterative search with killer/history quiet-move ordering and
Principal Variation Search; profiles, isolate execution, and performance
evidence remain.

| Phase | Deliverable | Exit evidence |
| --- | --- | --- |
| 1. Foundation | Stack decision, architecture, contracts, research, risks, CI, platform scaffold | All packages analyze/test; docs reviewed; no fake product controls |
| 2. Core engine | Immutable board/state, move application, serialization, replay/hash | Domain unit tests and property invariants |
| 3. American rules | Complete WCDF movement/capture/promotion/win/draw behavior | Federation-derived position corpus passes |
| 4. Board UI (complete) | Responsive accessible board, selection, move/capture highlights, motion primitives | 20 Flutter tests covering phone/tablet layouts, light/dark goldens, semantics, promotion, kings, capture branches, and keyboard play |
| 5. Single player (in progress) | Authoritative local session complete; persistence, clocks, undo policy, and resume remain | 18 session tests plus 21 Flutter regression/integration tests; end-to-end persistence evidence pending |
| 6. AI levels (in progress) | Contracts, beginner strategy, evaluation, fixed/iterative alpha-beta with PVS, cancellation, tactical and learned ordering, history-safe transpositions, bounded quiescence, and aspiration windows complete; ten profiles, isolate worker, and integration remain | 76 AI tests cover legality, determinism, tactics, budgets, cancellation, evaluation, ordering, cache safety, horizon avoidance, forcing captures, aspiration and PVS re-search, TT bounds, and killer/history reuse; fuzzing and device performance pending |
| 7. Regional rules | International, Brazilian, Russian, Turkish | Separate conformance corpus for every ruleset |
| 8. Story mode | Ten chapters, challenge evaluator, rewards, local progress | Objective/reward/unlock and migration tests |
| 9. Same-device | Two-player handoff/orientation, rematch | Full local match and restoration tests |
| 10. Local Wi-Fi | Room discovery/code fallback, host authority, reconnect | Two-device loss/rejoin and state-hash tests |
| 11. Bluetooth | Capability-gated platform adapters and pairing UX | Supported-device matrix; denial/loss/reconnect tests |
| 12. Backend | Serverpod, PostgreSQL, Redis, auth, migrations, observability | Integration suite and deployable staging environment |
| 13. Online play | Private rooms, quick/casual/ranked match, reconnect/draw/resign | Adversarial protocol, concurrency, and soak tests |
| 14. Profiles | Accounts, statistics, avatars, country, secure sessions | Privacy/auth/account lifecycle tests |
| 15. Rankings | Transactional Elo, divisions, seasonal leaderboards | Deterministic rating tests and anti-abuse review |
| 16. Achievements | Server/offline evaluators, sync, locked/unlocked UI | Idempotency and tamper-boundary tests |
| 17. Polish | Themes, sound, haptics, animations, reduced motion | Accessibility, audio-focus, and frame-time review |
| 18. Hardening | Coverage gaps, profiling, reliability, security testing | Release-candidate quality gates pass |
| 19. Release | Store metadata, signing, privacy disclosures, staged rollout | Android/iOS release candidates and rollback plan |

## Contribution policy

Commits should be small enough to review and large enough to describe a real
change. Empty commits, timestamp-only edits, and history spam are not used to
inflate the contribution graph. Feature branches should normally contain one or
more green commits; `main` remains releasable at phase boundaries.
