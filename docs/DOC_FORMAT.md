# How to write a scene / system doc

Format guide for every file in `docs/`. Follow it when asked to "make a doc/md for X" so the docs stay consistent. Existing examples: `debris_scene.md`, `line_hook_scene.md`, `character_scene.md`, `boat_scene.md`, `project_settings.md`.

**Purpose:** someone (or Claude) with only this file should understand how the thing is built and how it works, and be able to improve it. Describe what the code *does* and *why*; the appendix holds the exact code.

## File naming and location

- `docs/<thing>_scene.md` for a scene (`boat_scene.md`), `docs/<thing>.md` for other systems (`project_settings.md`).
- Lowercase, snake_case. One doc per scene/system. Link related docs with relative links (`[boat_scene.md](boat_scene.md)`).

## Before writing

1. Find the scene `.tscn` and **every** script, sub-scene, shader and resource it uses (`Glob`/`Grep` for the name; check `ext_resource` lines).
2. Read them fully. Also grep where the scene is instanced (levels, other scenes) and which other scripts reference it.
3. Check `project.godot` for input actions/layer names it uses.
4. Compare against `CLAUDE.md`. If the code contradicts it (moved/renamed/removed scripts), trust the code and note the discrepancy in the doc.
5. If a name is ambiguous (two things called "debris"), cover both and say so at the top.
6. Never guess: if not verified from the code, say it's unverified or leave it out.

## Structure (in this order)

```
# <Name> - scene reference
<1-3 sentences: what it is, what the player/game does with it>
- Scene: path      - Scripts: paths      - Related docs: links
> Repo note: (only if CLAUDE.md or comments are out of date)

---
## Node structure
   ASCII tree: node name (Type), script, key properties/layers/positions on the same line

## Physics layers        (layer + mask, decoded to layer names; who detects it)
## Components / Scripts  (one subsection per script)
## State / flow          (state machine, sequence diagram, or step list - if there is one)
## Exports / tuning      (table: export, default, meaning)
## Interactions          (other systems it touches: autoloads, groups, signals, other scenes)
## Where it's used       (levels/scenes that instance it, with positions/overrides)
## Open items / gotchas  (quirks, dead code, stale comments, missing pieces, ideas)

---
## Appendix: full source
   Note: "Copies as of writing; the repo is the source of truth."
   Every .tscn (trimmed if huge) and every script/shader, one code block each
```

Skip a section only if it truly doesn't apply. Add sections for anything unusual (e.g. animations table, spawner scripts).

## Style rules

- **Node tree:** use `├──`/`└──` box characters; put `script: x.gd`, `collision_layer=N (name)`, sizes, and positions inline.
- **Layers/masks:** always show the number *and* decode it to names from `project.godot` `[layer_names]` (e.g. `collision_mask=7 -> world | player | object`).
- **Tables** for exports, animations, input actions, and per-type comparisons. **Prose/bullets** for behavior.
- **Signals:** list connections as `Node.signal -> Target.method`.
- **Code references:** file paths in backticks in docs; include the function name that owns each behavior.
- **Explain why**, not just what (e.g. "reparents so it ignores parent transform", "order matters because X clears the flag").
- **Gotchas must be real:** dead code, hardcoded strings, stale comments, layer mismatches, unused exports, things that depend on node names. Each should be verifiable from the code.
- Use the project's spellings (e.g. `menue`, `Line-Hook`, `Pickable-Position`) exactly; note odd casing like `scenes/water/` vs `scripts/Water/`.
- Plain ASCII where practical (`->` not fancy arrows) so it renders anywhere. No emojis.
- Be concise; no filler. Detail goes in tables and the appendix.

## Appendix mechanics

Copy code with a shell script rather than retyping, so it's exact:

```bash
add() { # doc  title  lang  file  [start end]
  printf '\n### %s\n\n`%s`\n\n```%s\n' "$2" "$4" "$3" >> "$1"
  if [ -n "$5" ]; then sed -n "${5},${6}p" "$4" >> "$1"; else cat "$4" >> "$1"; fi
  printf '\n```\n' >> "$1"
}
add docs/x_scene.md "thing.gd" gdscript scripts/Foo/thing.gd
```

- Languages: `ini` for `.tscn`/`.godot`, `gdscript` for `.gd`, `glsl` for `.gdshader`.
- Huge `.tscn` (e.g. many `AtlasTexture` sub-resources): include only the node section and say so.
- For big shared scripts (e.g. `water_body.gd`), include just the relevant line range and label it `(lines A-B)`.
- Shared components used by several scenes (e.g. `grab_object.gd`) are included in each doc that depends on them.

## After writing

- Verify claims that cross files (e.g. "water_spring reads `receives_water_drag`") with a grep.
- Confirm the file's headings/appendix rendered (`grep -n '^##'`).
- In the reply: list what the doc covers, any discrepancies found with `CLAUDE.md`, and the quirks discovered. Don't edit `CLAUDE.md` unless asked.
