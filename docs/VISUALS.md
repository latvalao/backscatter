# BACKSCATTER — Visuals Plan

> Companion to `BACKSCATTER_DESIGN.md`. Engine: Godot 4.x, **Forward+ renderer** (required for volumetric fog, SSIL, SSR).
> Goal: low poly that looks **beautiful**, not retro. No pixelation, no PSX filter, no CRT.

---

## 0. How to use this document (for Claude Code)

- Art direction and rendering rules live here; gameplay/architecture rules live in the design doc. If they conflict, **gameplay readability wins**.
- Rendering is **presentation only** — nothing here may touch sim state (see design doc §0).
- Build visuals in the order of §13. Start with the **beauty corner** (one 500×500 m test scene) before scaling to full maps.
- All look settings (Environment presets, palettes, shader params) are **data**: `res://presentation/look/` resources, swappable per weather/season.

---

## 1. Why this matters

The current RTS wave looks the same: Ebbtide-style 3D pixel art, PSX-style filters, flat retro colour. Backscatter should be identifiable from **one screenshot** and **one capsule image**.

Core principle: **low fidelity geometry, high fidelity light.** Simple shapes rendered with modern lighting, atmosphere, depth haze and colour grading. Lighting and post-processing do most of the work; the meshes stay cheap.

---

## 2. Visual identity: "The Living Diorama"

The world looks like a **museum-grade military scale-model diorama** that has come to life — the kind of 1:35 Cold War dioramas hobbyists build: weathered tanks, static-grass fields, birch trees, mud, rust and wet concrete.

Why this fits:
- Military RTS players overlap heavily with scale modellers and wargamers — the look speaks to them directly.
- "Miniature" reads as **crafted and premium**, not cheap; low poly becomes a style choice.
- The diorama illusion comes naturally from a high camera angle + selective blur + saturated-but-controlled colour.
- Nobody else in the RTS wave is doing it.

### Visual pillars
1. **Diorama, not cartoon.** Realistic proportions, colours and materials, simplified geometry. Scale-model weathering, not toon shading.
2. **Northern light.** Low sun, long shadows, overcast diffusion, fog over bogs. The Nordic atmosphere is the hero.
3. **The battlefield remembers.** Tracks, craters, wrecks, fallen trees and smoke persist — every match ends looking different.
4. **Readable at a glance.** Beauty never hides units. Clear silhouettes, clear team markers, clear threats.
5. **Radiation through instruments.** No glowing ground. Radiation is shown with dosimetry overlays, grain, audio and consequences — keeping it grounded.

### Reference board (mood, not to copy)
- Scale-model dioramas: weathered 1:35 armour on forest bases, winter dioramas.
- Bad North / Townscaper (crisp low poly + soft light), Manor Lords & Against the Storm (atmosphere), Road to Vostok (Nordic border mood), S.T.A.L.K.E.R. (zone decay), Chernobyl (HBO) colour palette.
- Finnish/Karelian landscape photography: autumn birch, bogs at dawn, first snow on pines.

---

## 3. Colour

### 3.1 Palette (base swatches; graded per weather/season)

| Use | Hex | Note |
|---|---|---|
| Pine needles | `#2F4A3A` | Deep, slightly blue green |
| Moss / grass | `#6B7A4A` | Desaturated — never neon grass |
| Autumn birch | `#C9A13B` | Key accent colour of the world |
| Birch bark | `#E6E2D6` | Bright verticals in forests |
| Bog / peat | `#5A5238` | |
| Lake water | `#3E4E55` | Dark, reflective |
| Concrete | `#8A8D86` | Soviet-era panels, slightly green |
| Rust | `#8C4B2F` | Sparingly |
| Overcast sky | `#B8C2C4` | |
| Coalition camo base | `#4F5A3E` | + splinter darker `#343B2A` |
| Eastern olive base | `#5B5A3A` | + three-tone brown `#5E4B33` / black |
| UI amber (dosimetry, warnings) | `#E0B54A` | Reserved for UI/instruments |
| UI signal cyan (EM/DF overlay) | `#5FC7D1` | Reserved for UI/instruments |

### 3.2 Colour rules
- **Warm highlights, cool shadows**, with vignette, as the default grade.
- Keep saturation controlled; let specular highlights roll off to desaturated tones.
- Amber and cyan exist **only** in UI and overlays so information always pops off the muted world.
- One **accent per scene** (autumn birch gold, sunset orange, snow white). Don't stack accents.
- Team identity is never carried by vehicle paint alone (camo is realistic and similar) — see §10.

---

## 4. Lighting

Lighting matters most. Every map gets a lighting preset per time of day + weather.

- **Single directional sun**, low angle (10–35°) for long shadows across fields and through forests. Backlighting from the sun on tree lines and ridges = instant beauty.
- **Sky fill:** a procedural or HDRI sky as ambient source so shadows are never black. Overcast presets push ambient high and key low.
- **Indirect light:**
  - **SSIL** (screen-space indirect lighting) on Medium+.
  - **SSAO** always on (contact shadows under vehicles, in trenches, between trees).
  - **Baked vertex AO** in assets (see §6) so Low settings still look grounded.
  - **SDFGI only as an optional Ultra setting** — expensive on large maps.
- **Shadows:** directional shadow with 3–4 cascades, tuned for the RTS camera range. Soft but defined. Contact shadows from SSAO.
- **Local lights (night):** muzzle flashes, burning wrecks, vehicle headlights, illumination flares, FOB floodlights, the plant's warning lights. Night battles should be the most beautiful screenshots in the game.
- **Light shafts** through birch/pine canopy via volumetric fog + shadowed sun.

### Time-of-day presets (v1)
| Preset | Sun | Mood |
|---|---|---|
| Dawn mist | 8°, warm pink-orange | Fog in bogs, long shadows |
| Overcast day | diffused, cool | Default readable gameplay light |
| Golden afternoon | 20°, warm | Autumn birch glows |
| Storm | dim, green-grey | Rain, wet surfaces, lightning |
| Dusk | 5°, red | Silhouettes |
| Night | moon + aurora | Flares, fires, headlights |

---

## 5. Atmosphere

- **Depth haze** (Godot non-volumetric fog) always on: separates foreground and background, sets mood, hides map edges.
- **Volumetric fog:** global density low; **FogVolumes** placed in bogs, river valleys, forest hollows, around the plant cooling towers. Use `NoiseTexture3D` density for drifting wisps. Volumetric fog has finite range, so combine it with depth haze.
- **Weather systems** (presentation of the sim's weather state):
  - Rain: GPU particle rain near camera, wet shader on all materials (darker albedo, lower roughness, SSR reflections on roads/concrete), ripples in puddles, droplets on water.
  - Fog: increase haze + volumetric density; optics range matches sim visibility.
  - Snow: falling snow particles + **snow accumulation shader** (top-facing normals turn white, increasing over the match).
  - Wind: drives foliage sway, smoke direction, rain angle — and matches the sim wind that drives fallout plumes (so players can *see* where fallout will go).
- **Night sky:** stars + **aurora borealis shader** on clear northern nights. A signature screenshot.
- **Smoke:** artillery smoke, burning wrecks, smoke screens — lit by sun and fires, drifting with wind, casting soft shadows into volumetric fog where affordable.

---

## 6. Materials & shading

### 6.1 Base approach
- **Flat-shaded low poly** (hard normals) for man-made objects; **soft normals** for terrain and foliage clumps (prevents faceted "90s" look on nature).
- **Palette texture workflow:** most assets UV-mapped onto one small **gradient palette atlas** (e.g. 256×256) → tiny memory, consistent colour, easy recolours per faction/season.
- **Vertex colours carry baked data:** R = ambient occlusion, G = curvature (edges), B = dirt mask, A = custom (e.g. rust zones).

### 6.2 "Scale-model weathering" uber-shader (vehicles, buildings, props)
One shared spatial shader, parameters per material:
- **Dry-brush edge highlight:** lighten edges using curvature (G channel) — the classic scale-model trick that makes low poly shapes pop.
- **Wash / panel shading:** darken crevices using AO (R channel).
- **Height-based grime:** world-space gradient from ground up (mud and dust on lower hulls).
- **Dynamic mud:** a per-instance uniform `mud_amount` raised when vehicles drive through bog/field cells (sim terrain), lowered in rain.
- **Wetness:** global uniform from weather — darker albedo, lower roughness.
- **Snow:** global `snow_amount` × upward-facing normals.
- **Burn / destroyed state:** blend to charred black-brown, emissive embers fading out.
- **Contamination hint (subtle, optional):** faint dust/discoloration on contaminated vehicles — never glow.
- **Subtle surface noise** (triplanar, low-frequency) to break flat colour without textures.

### 6.3 Terrain
- Heightmap terrain with **splat blending** of 4–8 layers: field grass, forest floor, bog, mud, gravel road, asphalt, snow, burnt ground.
- Triplanar on slopes/cliffs (granite outcrops).
- Painterly macro-variation: large-scale noise tints (patches of yellow grass, darker moss) so fields look like a diorama base with flocking.
- **Deformation layer:** a render-target "trail map" storing tank tracks, wheel ruts, footprints in snow/mud, and **craters**. Sampled by terrain shader (darken/flatten albedo, optional vertex offset on High). Persists for the whole match.
- Scorch decals for explosions, oil stains at FOB, road markings.

### 6.4 Water
- Dark, still lakes and bog pools: depth-based colour, SSR + sky reflection, soft shoreline foam, rain ripples. Reflections of birches in still water at dawn = hero shot.

---

## 7. Foliage — the forest is the star

Forest is both the game's beauty and a core gameplay mechanic (LOS, cover).
- **Species:** Scots pine, spruce, silver birch, aspen, juniper shrubs, reeds, heather. Low poly trunks + low poly leaf-clump meshes (no flat cards up close).
- **Instancing:** `MultiMeshInstance3D` per species per terrain chunk; distance LOD (mesh → simplified mesh → **impostor billboards** far away).
- **Per-instance variation:** hue/brightness shift, scale, rotation, lean.
- **Wind sway** vertex shader: trunk bend + leaf flutter, amplitude from weather wind.
- **Seasonal tint:** autumn birch gold → bare branches → snow-laden pines, driven by a season uniform.
- **Destruction:** tanks knock down small trees (swap instance to fallen variant), artillery strips and burns forest sections — persists all match.
- **Readability (critical):** units under canopy must stay visible:
  - **Canopy dither-fade** within a radius around selected/hovered units and near the camera's focus.
  - **Silhouette x-ray** (team-coloured outline) for friendly units occluded by trees/buildings; spotted enemies get a red outline.

---

## 8. Camera & post-processing

### 8.1 Camera
- Perspective camera, FOV ~35–45° (narrower FOV = more diorama), pitch 45–65°, smooth zoom.
- **Zoom-dependent tilt-shift:** depth-of-field focus locked to the ground point under screen centre; blur increases with camera height. Heavy defocus adds both realism and a miniature look. Off by default in competitive versus settings if players prefer clarity.
- Subtle camera smoothing and inertia; slight auto-tilt toward horizon when zoomed in close (cinematic), top-down-ish when zoomed out (tactical).

### 8.2 Post stack (in order)
1. SSAO + SSIL + SSR (quality tiered)
2. Volumetric fog + depth haze
3. Tilt-shift DOF (zoom-driven)
4. Bloom / glow — subtle, mainly for fires, flares, muzzle flashes
5. **Colour grading LUT** per weather/time preset (warm highlights, cool shadows)
6. Film grain — very light; increases slightly when the camera is over high dose-rate areas (instrument-like unease)
7. Vignette — light
8. Optional **thin ink outline** post-process (depth/normal edge detection) at low opacity on silhouettes — test it; ship it only if it improves readability without looking cartoony.

### 8.3 Retro filter (changed by the project owner, replaces the old ban)
A retro screen filter is part of the look. It is applied to the 3D world only; the HUD, NATO symbols and text stay sharp.
- Stable pixel blocks (2 px Subtle, 3 px Full, scaled with window height), each block the average of four sharp samples so it doesn't shimmer.
- Palette lock: ordered dither, then snap to a curated palette built from palette.json (tools/gen_retro_lut.py -> retro_lut.png).
- Ink edges where neighbouring blocks differ sharply.
- Radiation speckle: single white blocks, like fogged film, scaling with the dose rate under the camera.
- Settings: Off / Subtle (default) / Full.
Still avoid: PSX vertex wobble, CRT/VHS curvature and scanlines, chromatic aberration, heavy lens flares, toon ramps.

---

## 9. Signature features (what makes screenshots and trailers)

### 9.1 Topographic map zoom ("Staff Map")
Zoom out past a threshold and the 3D world **cross-fades into a military staff map**: paper texture, contour lines generated from the heightmap, forests as green hatching, roads, grid squares with map references, units as **NATO-style tactical symbols** (APP-6 look: rectangles for friendly, diamonds for hostile), arrows for movement orders, artillery fire missions as drawn circles.
- Gameplay value: macro control and readability for large battles.
- Visual value: nobody's strategic zoom looks like a hand-drawn Cold War staff map.
- Implementation: render the map layer as a separate viewport/shader over the terrain; fade 3D out, map in, by camera height.

### 9.2 Dosimetry overlay
Radiation is shown as **survey-map isolines** (contour lines of dose rate) in UI amber, with numeric labels like a real radiological survey, plus wind arrow and plume forecast. Clean and technical, never glowing goo.

### 9.3 Signal overlay (backscatter)
EM emissions and enemy DF **bearing lines and uncertainty ellipses** drawn in signal cyan, like an EW operator's plot. Ellipses tighten as triangulation improves.

### 9.4 Seasons
Campaign and skirmish maps support **Autumn / First Snow / Winter / Spring thaw (mud)** variants. Same geometry, different look and gameplay (snow tracks, mud slows wheels). Effectively 4× the visual variety for little asset cost.

### 9.5 Battlefield persistence
Tracks, craters, burnt forest, fallen trees, wrecks (with lingering smoke and fire), abandoned helmets and spent shell casings around artillery. End-of-match screenshot = story of the battle. Optional **"photo mode"** for players to share dioramas — free marketing.

### 9.6 Night flares
Parachute illumination flares slowly drifting down, casting moving shadows through the forest. Night attacks become cinematic.

---

## 10. Readability rules (RTS first)

- **Silhouette first:** every unit type recognisable by silhouette at mid zoom. Slightly **exaggerate scale** of vehicles and infantry (≈1.3–1.5×) relative to buildings/trees — dioramas do this too.
- **Team identity:** small team-coloured ground ring/decal under units, coloured selection brackets, and tactical-symbol icons on hover/zoom — not vehicle paint.
- **Health/status:** minimal floating bars only when damaged or selected; crew/dose detail in unit card.
- **Threat cues:** tracers brightly visible (team-tinted), ATGM smoke trails, artillery incoming markers on the ground before impact.
- **Muted world, bright information:** environment stays within the palette; UI, overlays, tracers and markers own the saturated colours.
- Accessibility: colour-blind safe team palettes, option to disable DOF, grain, outlines and camera tilt.

---

## 11. VFX list (v1)

| Effect | Notes |
|---|---|
| Muzzle flash | Short omni light + sprite; dust kick-up on tanks |
| Tracers | Bright, team-tinted, readable at all zooms |
| Tank shell impact | Dust + sparks; penetrating hit = internal fire glow from hatches |
| Vehicle destruction | Turret pop-off (MBT-72 style ammo cook-off), burning wreck, lingering smoke column |
| Artillery | Incoming whistle + ground marker, big dirt plume, crater decal + trail-map crater |
| MLRS salvo | Rocket trails streaking across the sky — hero shot |
| Smoke screen | Thick, wind-driven, blocks LOS (matches sim) |
| ATGM | Visible missile + smoke trail (wire-guided: faint wire line) |
| Drone | Small, with subtle prop blur; jammed drones wobble and fall |
| Illumination flare | Moving light + parachute |
| Rain/snow | Near-camera GPU particles |
| Decontamination | Vehicles being sprayed at decon points (steam/foam) |
| Dust trails | Vehicles on dry roads raise dust (gives away movement — matches spotting) |

---

## 12. Asset pipeline & budgets

- **Tool:** Blender. Flat shading on hard-surface, palette-atlas UVs, vertex colour bake (AO, curvature, dirt) via Blender bake → vertex colours, export glTF 2.0.
- **Poly budgets (LOD0):** infantry soldier 300–600 tris; light vehicle 1.5–3k; MBT/IFV 3–6k; building 1–5k; tree 300–1.5k (impostor at distance).
- **LODs:** 3 levels for vehicles/buildings; automatic mesh LOD from Godot import + manual for hero assets.
- **Animation:** infantry with a shared low-poly rig and a small animation set (idle, walk, run, prone, crawl, fire, throw, die). Vehicles: turret/gun rotation, track UV scroll, suspension bounce, wheel spin.
- **Naming & folders:** `res://presentation/assets/{faction}/{unit_id}/` matching sim unit IDs.
- **Performance targets:** 60 FPS at 1440p on GTX 1660-class with Medium preset; 300+ units, dense forest.
- **Quality presets:** Low (no volumetric fog, SSAO only, fewer foliage instances), Medium, High (SSIL, SSR, volumetrics), Ultra (SDFGI, higher volumetric resolution, terrain vertex deformation).

---

## 13. Build order (aligned with design doc milestones)

### V0 — Beauty corner (alongside design M1)
One 500×500 m scene: lake shore, birch/pine forest edge, bog with fog, a road, a ruined border post, one MBT-72 and one MBT-2A, golden-afternoon preset.
- **Accept:** a screenshot that already looks like a diorama photo; 60 FPS on target hardware.

### V1 — Look system
WorldEnvironment presets as resources, time-of-day + weather blending, colour grading LUT pipeline, tilt-shift camera, quality presets.
- **Accept:** switching presets at runtime is seamless; all presets readable for gameplay.

### V2 — Uber-shaders
Scale-model weathering shader, terrain splat + trail map, foliage wind/season shader, water shader, canopy dither-fade + x-ray silhouettes.
- **Accept:** a vehicle driving through bog gets muddy and leaves tracks; units under trees remain visible.

### V3 — Weather & seasons
Rain (wetness + puddles + SSR), fog volumes, snow accumulation, aurora night sky, seasonal foliage/terrain variants.
- **Accept:** same map in Autumn and Winter looks like two different dioramas.

### V4 — VFX & persistence (alongside design M2/M5)
Full VFX list, craters, wrecks, burnt forest, fallen trees, smoke columns.
- **Accept:** a 20-minute battle leaves a visibly scarred, story-telling battlefield.

### V5 — Overlays & staff map (alongside design M5/M6)
Dosimetry isolines, signal/DF overlay, staff map zoom with NATO-style symbols.
- **Accept:** a player can run a battle entirely from the staff map zoom.

### V6 — Polish & marketing
Photo mode, capsule art and trailer shots (dawn mist, MLRS salvo at dusk, night flares in forest, winter column on frozen lake).

---

## 14. Pitfalls to avoid
- Over-saturating grass and trees → instantly "mobile game".
- Beauty effects that hide units (fog, DOF, canopy) — always test with gameplay on.
- Too many accent colours or glowing effects → loses the grounded tone.
- Mixing styles (pixel textures on low poly, realistic textures on some assets only) — keep everything on the palette-atlas workflow.
- Volumetric fog everywhere → GPU cost; use FogVolumes where it matters.
- Smooth normals on hard-surface low poly → blobby 90s look.
