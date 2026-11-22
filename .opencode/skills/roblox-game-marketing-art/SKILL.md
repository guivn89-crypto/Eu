---
name: roblox-game-marketing-art
description: Create and refine Roblox game discovery icons, thumbnails and ad images using this user's visual preferences, what won as ads in their past games, reference research, approved-art continuity, and the image-generation route that works (Codex, or Gemini in Chrome when Codex has no image tool). Use for promotional artwork, not in-game GUI design.
---

# Roblox game icons and thumbnails

These are preferences learned while making artwork for past games, not universal rules for every Roblox game. Follow the current request when it differs.

## Reference research

Inspect actual images before choosing a direction. A game page's large promotional thumbnail is not its square discovery icon. Inventory pages can contain many historical variants; inspect more than the first visible row when useful. Do not infer authorship, conversion performance or official status merely from inventory ownership. Learn compositions and visual clarity; adapt to the current game's real mechanics.

Useful reference collection: https://www.roblox.com/users/537836346/inventory/#!/places . Pages 1–2 inspected September 2026 show split comparisons, small-to-large crops, players for scale, and close-up crop rewards. Their existence is not evidence of performance.

## Visual preferences

- Prefer authentic Roblox promotional renders or staged screenshot appearance. Avoid glossy Pixar-like toy renders, cinematic bloom, over-modelled hair and busy decorative scenes.
- Classic bacon hair should resemble the normal smooth brown Pal Hair accessory: broad curved strips and modest brown highlights, not orange faceted shards. Use the supplied/approved reference for identity.
- Make gameplay or its payoff immediately visible. One clear action or progression contrast beats a collection of unrelated props.
- Keep the background sparse. Baseplate studs should be small, low contrast and close to Roblox's actual surface. Giant rounded raised pegs are a recurring generation error; do not call an approximation exact. For exact fidelity use an actual supplied/Studio surface reference.
- Objects should have sensible rigid geometry. Carrots repeatedly curved inward accidentally: their tips should stay on their own straight centerlines; moving objects together does not mean bending them.
- Faces are intentional. This user liked a mischievous half-lidded toothy grin for the confident character. Use a curious expression when a concept calls for uncertainty; do not silently replace an approved face with wide-eyed cheerfulness.
- Arrows, halos and sunburst rays were tried and removed in past icons. Treat those as disfavored defaults, not permanent prohibitions.
- For progression split icons, express the change through imagery without BEFORE/AFTER text when requested. Keep the same recognizable character across halves. Relate wealth to the game's actual economy.

## Iteration discipline

Use the imagegen workflow for raster generation/editing. Select the exact version the user identifies, especially when they reattach an older image. Later versions are not automatically preferred.

For narrow edits, preserve camera, pose, composition, identity and untouched objects explicitly. Separate reference roles: edit target vs hair reference vs face reference. Do not import a reference's unwanted background, lighting or other traits.

Inspect outputs for requested changes before reporting success. Common failures: carrots still bent, face drift, character appearing buried after reframing, overly prominent fictional studs, residual arrows/glow. Fix targeted failures rather than redesigning approved elements.

Save versioned images and exact prompts in the project's marketing-art directory, preserving previous versions. Square icons are the default established here; confirm or infer the intended thumbnail aspect ratio from the request rather than stretching a square asset. No upload or publish is implied by making art.

## What won as ads
- Winners showed **one simple, satisfying action with a huge object or a huge mass of identical things**, a clean
  background and no text. Losers: "E" prompt labels, Day 1 / Day 50 text, rarity %, busy scenes. Keep the project's
  own ad results table (`marketing/research/ad-results.md`) and read it before a new round.
- The bacon-hair player happily doing the core action, the threat (if the game has one) big and clear behind them;
  warnings in red, not cash; no "New!" bubbles.
- When copying a competitor's layout, the prompt says "layout only, never its characters" (their animals got
  copied once).
- Work in a script (`marketing/thumbnails/generate.py`: jobs, versions, prompts saved next to each image) and a
  local gallery with stars for the user's picks (`marketing/gallery/`).

## Image route when Codex has no image tool
The free Gemini web app in the user's Chrome (Claude in Chrome): one tab, one image at a time (several tabs at once
triggered Google's "unusual traffic" CAPTCHA); attach references through the file input after clicking "+"; short
prompts with an approved render of our own as the style reference work best. Saving: "Download full size" stops
landing after the first image, so use the image's "Copy image" button, then save the clipboard PNG with
`osascript` (`the clipboard as «class PNGf»`) into the job (that copy is the 1024 px preview: upscale for
1920x1080). ~20 s an image.

## Provenance

Keep each approved baseline in the project's marketing-art directory with its prompt alongside it, and note which earlier version supplied which approved trait (expression, hair, framing). Read the current game's mechanics before inventing promotional features.
