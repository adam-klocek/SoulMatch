# SoulMatch / Modern Romance

**Connection, considered.** A quietly romantic, inclusive place for love, friendship, or both.

| Token | Colour | Use |
| --- | --- | --- |
| Deep Teal | #364F4B | Navigation, headings, primary actions, outgoing messages |
| Muted Coral | #D58B80 | Selected intentions/interests, mutual romantic connection accents |
| Soft Peach | #E9B8A5 | Warm highlights, editorial imagery and secondary details |
| Warm Ivory | #F4EDE6 | Page canvas and atmosphere |
| Lavender | #B59AC6 | Reflection progress, fit indicators, friendship accents |

Light tinted surfaces carry dark teal text. Coral/lavender are accents, not low-contrast white-text button backgrounds. Supporting paper is #FFFCF8. The platform system sans provides clear application headings and controls, with Georgia used for selective editorial emphasis and numbers without external font tracking/downloads. The interlaced loop mark suggests two independent lives meeting, without a heart motif.

- Cards: 20–25px corners; restrained borders and shadows.
- Buttons: softly rounded, readable dark teal primary actions; minimum 42px height (46px on principal mobile choices).
- Mobile: horizontally scrollable navigation with visible labels; stacked cards; a segmented Love/Friends selector; profile preferences disclosed progressively.
- Desktop: centered full-width workspace, horizontal navigation, balanced discovery columns, three-column module grid and two-/three-column connection cards.
- Questionnaire: small batches, honest progress, clear optional labels, save/resume, native keyboard-accessible controls.
- Motion: short colour/progress transitions with a reduced-motion fallback.
- Photography: fictional adults, daylight, ordinary clothing and natural expressions; no glamour hierarchy or appearance ratings.
- Language: warm, specific, nonjudgmental. Fit points invite exploration and never imply validated romantic probabilities.

`mobile-design-board.svg` / `.png` preserve the earlier 0.2 illustrative reference; they do not represent the revised 0.3 navigation and tile layouts. They are not browser screenshots or evidence of real matches. Actual UI source lives in `R/ui.R`, `R/server.R`, `R/interests_modules.R`, `R/height.R`, `R/world.R`, and `www/app.css`.


Self-discovery uses six tile buttons. Completion lightens the card surface without reducing text opacity or contrast, and adds an explicit checkmark and Completed label. Forms appear only after selection; each module has a clear return to the collection. My world uses public profile details and seven aggregate comparisons; private item responses never appear in a connection card. Missing metrics use labeled dashed tracks, and mutual requests use an explicit text badge rather than color alone.
