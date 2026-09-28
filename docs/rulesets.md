# Ruleset research baseline

This document records the implementation baseline; it is not a substitute for
per-ruleset conformance tests. Each ruleset must ship with opening-position,
capture-path, promotion, win, and draw fixtures traced to its governing source.

| Ruleset | Board / pieces | Men | Kings | Capture choice | Promotion during capture |
| --- | --- | --- | --- | --- | --- |
| American Checkers / English Draughts | 8x8, 12 per side, dark squares | Step and capture diagonally forward | One square diagonally; capture forward/back | Capture mandatory; any complete sequence may be chosen | Reaching king row ends the turn |
| International Draughts | 10x10, 20 per side, dark squares | Step forward; capture forward/back | Flying diagonal movement/capture | Mandatory sequence taking the greatest number of pieces | A man crossing but not ending on the crown row remains a man |
| Brazilian Draughts | 8x8, 12 per side, dark squares | Step forward; capture forward/back | Flying diagonal movement/capture | Mandatory maximum-piece sequence | A man that reaches the crown row during capture stops and crowns; it does not continue as a king |
| Russian Draughts | 8x8, 12 per side, dark squares | Step forward; capture forward/back | Flying diagonal movement/capture | Mandatory capture; sequence choice is not maximized by piece count | A man reaching the crown row during a capture continues immediately as a king |
| Turkish Draughts | 8x8, 16 per side on rows 2 and 3 | Move/capture orthogonally forward or sideways; no backward capture | Flying orthogonally | Mandatory maximum-piece sequence; captured pieces are removed immediately | Crowns for the next move, not during the sequence |

## Sources and engine consequences

### American Checkers / English Draughts

The World Checkers/Draughts Federation rules define the 8x8 board, 12 pieces,
forward-only men, compulsory captures without a maximum-capture rule, short
kings, and a turn ending on promotion. The rules engine therefore needs a
`captureSelection: anyCompleteSequence` policy and `promotionTiming: endTurn`.

[WCDF Rules of Draughts (PDF)](https://wcdf.net/rules/rules_of_checkers_english.pdf)

Implementation status: `AmericanCheckersRulesEngine` implements WCDF rules
1.8-1.21 and board-derived results from rules 1.30 and 1.32. It tracks full
position history for third repetition and an 80-ply counter representing 40
moves by each player without a capture or uncrowned-man advance. Resignation,
timeout, forfeiture, and agreed draws remain session-level adjudications rather
than legal board moves.

### International Draughts

FMJD rules define the 10x10 board, backward capture by men, flying kings,
maximum-piece capture, delayed removal during a sequence, and promotion only
when the man finishes on the crown row. Draw counters differ materially from
the 8x8 games and must remain ruleset-owned.

[FMJD Official Rules for International Draughts (PDF)](https://www.fmjd.org/downloads/news/948/Annex%201%20official%20FMJD%20rules%20of%20international%20draughts.pdf)

### Brazilian and Russian Draughts

The official draughts-64 rules share the 8x8 flying-king base but explicitly
separate Brazilian capture priority and promotion behavior from Russian play.
Russian play lets a newly crowned man continue a capture as a king; Brazilian
play requires the greatest number of captures and stops the sequence when the
man promotes.

[Official Rules of Draughts-64 (PDF)](https://www.fmjd.org/downloads/64cb/Official_Rules_of_the_game_in_64_classic_draughts.pdf)

### Turkish Draughts

Turkish play is orthogonal, not diagonal. Men move forward or sideways, kings
range along ranks/files, the maximum capture is compulsory, men cannot capture
backward, and captured pieces are removed immediately. These differences
justify a board-geometry strategy rather than diagonal assumptions in generic
code.

[FMJD Turkish Draughts rules (PDF)](https://www.fmjd.org/downloads/td/TD_eng.pdf)

## Open questions for remaining rulesets

- Encode each remaining federation's draw rules, including material-specific
  move limits, as explicit namespaced counters rather than one generic rule.
- Confirm whether a product-friendly casual preset may differ from tournament
  rules; if offered, label it as a variant, never as the country ruleset.
- Validate notation orientation and starting-player conventions in fixtures.
- Have a knowledgeable player review at least one capture corpus per ruleset.

