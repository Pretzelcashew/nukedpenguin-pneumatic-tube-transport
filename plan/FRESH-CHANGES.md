### Revision: Diverter Downstream Lookahead Path Validation & Instant Queue Advancement
**Date:** 2026-08-30 18:28 (EDT)
**Context:** Resolve diverters backing up and blocking open routes by validating downstream capacity before committing capsules into internal machine hops, and eliminating queue latency on segment arrivals.
**Key Changes:**
1. **Recursive Downstream Lookahead Validation (`scripts/capsules/capsule-motion.lua`):** Implemented `is_hop_valid()` to inspect downstream external hops when evaluating internal machine transfers (e.g. diverter input-to-output ports). Ensures exit ports leading to full or filter-disqualified tube lines are rejected before a capsule enters the internal port.
2. **Pressure-Drop Scoring Filtering (`scripts/capsules/capsule-motion.lua`):** Updated `best_downstream` calculations in `select_next_target()` to evaluate pressure drop gradients exclusively across open downstream paths with available network capacity.
3. **0-Tick Queue Advancement (`scripts/capsules/capsule-runner.lua`):** Configured `update_capsules()` to fire `capsule_runner.wake_parked_capsules()` whenever any capsule completes a segment traversal (`to_port_key = nil`), allowing waiting capsules to re-evaluate pathing instantly on the same tick when space opens up.


### Revision: O(1) Spatial Occupancy Index & Zero-Allocation Path Lookahead Optimization
**Date:** 2026-08-30 20:25 (EDT)
**Context:** Restore UPS performance during high capsule traffic (~150+ active capsules) by eliminating O(N) linear iteration over active capsules and string garbage allocations occurring during recursive path lookahead capacity checks (`is_hop_valid`, `get_capsule_count_at_entity_network`).
**Key Changes:**
1. **$O(1)$ Spatial Occupancy Index (`scripts/capsules/capsule-queries.lua`):** Implemented `storage.occupancy` to track multi-level spatial buckets (`[unit_number][net_id][group]`), converting `get_capsule_count_at_entity_network`, `get_capsule_count_at_entity`, and `find_capsules_at_entity` into constant-time lookups. Added tracking utilities (`update_capsule_occupancy`, `unregister_capsule_occupancy`, `rebuild_occupancy_index`).
2. **Memoized Port Key Parsing (`scripts/capsules/capsule-queries.lua` & `scripts/capsules/capsule-motion.lua`):** Added `get_port_info()` to cache parsed port key descriptors (`unit_number`, `port_index`), eliminating string slicing (`string.sub`) and string concatenation garbage inside high-frequency `get_unit_number()` and diverter filter evaluations.
3. **Occupancy Lifecycle Integration (`scripts/capsules/capsule-runner.lua` & `scripts/capsules/capsule-motion.lua`):** Synchronized occupancy tracking updates across capsule injection (`inject_from_hub`), segment transitions, target selection (`select_next_target`), hub capture disembarkation, emergency ejection, and entity removals.


### Revision: Targeted Network-Scoped Queue Wakeup Engine & Retry Throttling
**Date:** 2026-08-30 20:56 (EDT)
**Context:** Eliminate global map-wide capsule scans triggered during individual segment movements and arrivals, restoring UPS performance and parked retry throttling during high capsule traffic.
**Key Changes:**
1. **Targeted Wakeup Engine (`scripts/capsules/capsule-runner.lua`):** Refactored `capsule_runner.wake_parked_capsules` to accept an optional target (`port_key`, `unit_number`, or `net_id`), utilizing `storage.occupancy` and network topology metadata to wake strictly the parked capsules affected by a freed route or entity state change.
2. **Network-Scoped Movement Hooks (`scripts/capsules/capsule-runner.lua`):** Updated segment movement completions, hub disembarkations, capsule removals, and emergency ejects to pass the exact vacated `port_key` to `wake_parked_capsules`, eliminating blanket map scans on individual movement steps.
3. **Restored Retry Throttling (`scripts/capsules/capsule-runner.lua`):** Ensured parked capsules on unaffected tube lines or separate surfaces remain asleep for their full 10-tick interval (`PARKED_RETRY_INTERVAL = 10`), preventing tick-by-tick pathfinding and filter re-evaluations across the map.


### Revision: System-Level Viewport Caching & Zero-Allocation Render Loop
**Date:** 2026-08-30 21:13 (EDT)
**Context:** Eliminate per-capsule player environment queries, game view setting reads, string key joins, and temporary table allocations occurring inside the per-tick render loop (`capsule_renderer.render`) to restore UPS performance during high capsule traffic.
**Key Changes:**
1. **System-Level Per-Frame Viewport Preparation (`scripts/capsules/capsule-renderer.lua` & `scripts/capsules/capsule-runner.lua`):** Implemented `capsule_renderer.prepare_frame()` invoked at the start of `update_capsules()`, pre-evaluating player viewport eligibility, Alt Mode states, and active debug flags once per tick across `game.players` instead of $N_{\text{capsules}} \times N_{\text{players}}$ times per frame.
2. **Memoized Numeric Hover Peeking (`scripts/capsules/capsule-renderer.lua`):** Replaced string formatting (`tostring(unit_number) .. ":"`) and string slicing (`string.sub`) during hover peeking (`/capsule-peek`) with memoized $O(1)$ unit number lookup via `capsule_queries.get_port_info()`, enabling fast integer equality comparisons (`u_from == hovered_unit`).
3. **Allocation-Free Scratch Tables & Fast Numeric Debug Keys (`scripts/capsules/capsule-renderer.lua`):** Replaced per-capsule temporary table allocations (`debug_players`, `debug_key_tbl`) and string joins (`table.concat`) with pre-allocated module-level scratch arrays (`scratch_debug_players`, `scratch_debug_keys`) and numeric primitive cache keys (`0` or `player.index` for 0/1 viewers).


### Revision: Mid-Segment Traversal Parameter Caching & O(1) Motion Interpolation Loop
**Date:** 2026-08-30 21:59 (EDT)
**Context:** Eliminate repetitive mid-segment node lookups, physical entity coordinate queries, and speed math calculations (`calculate_segment_speed`, `get_port_world_pos`) executed every tick for capsules currently in mid-transit, restoring UPS performance during high capsule traffic (~150+ active capsules).
**Key Changes:**
1. **Segment Traversal Parameter Caching (`scripts/capsules/capsule-motion.lua`):** Implemented `setup_segment()` to pre-calculate and cache segment start/end world coordinates (`seg_from_x`, `seg_from_y`, `seg_to_x`, `seg_to_y`), vector deltas (`seg_dx`, `seg_dy`), total segment distance (`seg_dist`), surface (`surface`), entity handles (`entity_from`, `entity_to`), and travel speed (`seg_speed`) directly on capsule objects upon target selection and segment transitions.
2. **$O(1)$ Mid-Segment Motion Loop (`scripts/capsules/capsule-runner.lua`):** Updated `update_capsules()` to interpolate mid-segment movement directly from cached primitive parameters, bypassing per-tick `calculate_segment_speed()`, `get_port_world_pos()`, and `get_node()` queries. Replaced per-tick `{ x = ..., y = ... }` position table allocations with a module-level scratch position table (`scratch_pos`) and fast C++ property checks (`entity_from.valid`, `entity_to.valid`).
3. **Cached Location Queries (`scripts/capsules/capsule-runner.lua`):** Refactored `get_capsule_location()` to return real-world coordinates directly from cached segment parameters in $O(1)$ time, eliminating network topology node queries during passenger position updates, emergency ejects, and spoilage unit handling.


### Revision: Target-Based Spatial Occupancy & 0-Tick Pipeline Queue Advancement
**Date:** 2026-08-30 22:22 (EDT)
**Context:** Eliminate network queue stalling, 1-by-1 segment traversal delays, and stale spatial occupancy indexes following network rebuilds, segment additions, or flow updates.
**Key Changes:**
1. **Target-Based Blocking Occupancy Model (`scripts/capsules/capsule-queries.lua`):** Refactored `update_capsule_occupancy` to track a single node blocking key (`_occ_block_key`). Moving capsules block their destination target (`to_port_key`), immediately freeing origin node capacity (`from_port_key`) for upstream capsules while in mid-transit.
2. **0-Tick Lockstep Queue Advancement (`scripts/capsules/capsule-runner.lua`):** Configured `update_capsules()` to invoke `wake_parked_capsules(prev_from)` the exact tick a parked capsule transitions to moving (`to_port_key ~= nil`), triggering instant pipeline wakeups for upstream queued capsules without 10-tick retry delays or segment arrival latency.
3. **Synchronized Occupancy Resync & Listener Propagation (`scripts/networks/networks-flow.lua` & `scripts/capsules/capsule-runner.lua`):** Configured `networks_flow.build()` to invoke `capsule_queries.rebuild_occupancy_index()` on graph edits, and updated `notify_listeners` and `wake_parked_capsules` to process network ID tables, instantly waking sleeping capsules across modified or rebuilt subgraphs.


### Revision: Zero-Allocation Payload Metadata Caching & Motion Inventory Bypass
**Date:** 2026-08-30 22:38 (EDT)
**Context:** Eliminate physical container item stack inspections on the liminal surface (`get_dominant_item`) during directional path selection, diverter filter evaluations, and hub exit checks (`select_next_target`, `find_best_hub_outbound_port`) to restore UPS performance during high capsule traffic (~150+ active capsules).
**Key Changes:**
1. **Payload Metadata Caching at Packing (`scripts/hubs/hub-packing.lua` & `scripts/capsules/capsule-manager.lua`):** Updated hub packing logic to compute the dominant payload item during extraction plan generation and pass it directly to `capsule_manager.register()`, persisting it in `storage.active_capsules[capsule_id].dominant_item`.
2. **$O(1)$ Motion Pathfinding & Filter Evaluation (`scripts/capsules/capsule-motion.lua` & `scripts/capsules/capsule-runner.lua`):** Refactored `select_next_target()` and `find_best_hub_outbound_port()` to read `capsule.dominant_item` directly from memory in constant time, bypassing C++ container inventory queries on `liminal_surface` during tick-by-tick motion execution and diverter filter evaluations.
3. **Guarded Renderer Inventory Scans (`scripts/capsules/capsule-renderer.lua`):** Updated `capsule_renderer.get_dominant_item(capsule_id, force_refresh)` to return cached payload strings instantly, restricting physical container inventory scans to explicit force-refresh calls (e.g., 60-tick spoilage re-checks for active Alt Mode debug overlays).


### Revision: Diverter Filter Validation & O(1) Key Parsing Optimization
**Date:** 2026-08-30 22:54 (EDT)
**Context:** Eliminate redundant string key parsing, deep network graph flow-map lookups, and uncompiled settings table traversals during tick-by-tick diverter filter evaluation and recursive lookahead pathfinding.
**Key Changes:**
1. **$O(1)$ Non-Diverter Filter Short-Circuiting (`scripts/capsules/capsule-motion.lua`):** Refactored `check_diverter_port_filter()` to query `capsule_queries.get_port_info()` directly, extracting integer unit numbers and port indices without flow-map metadata traversals or string allocations, instantly short-circuiting non-diverter entities in 2 table lookups.
2. **Memoized Filter Compilation & Active Slot Traversal (`scripts/capsules/capsule-motion.lua`):** Implemented `get_compiled_filter()` to lazily compile active filter slots and blacklist modes onto `port_setting._compiled`, bypassing unconfigured slots (slots 2..5) and enabling instant early-exit evaluation on whitelist matches.
3. **Graph-Free Unit Key Parsing & Filter Cache Invalidation (`scripts/capsules/capsule-motion.lua` & `scripts/networks/diverter-manager.lua`):** Refactored `get_unit_number()` to delegate directly to memoized port info lookups, and updated `diverter_manager` (`notify_settings_changed`, `check_diverter_states`) to clear `_compiled` caches on modified diverter ports when settings, orientation, or power states change.


### Revision: O(1) Hub Unpacking Failure Guard & Zero-Allocation Space Simulation
**Date:** 2026-08-30 23:32 (EDT)
**Context:** Eliminate redundant full-container slot space simulations (`can_insert_all`) performed by capsules parked at or repeatedly polling full or blocked hub destinations, restoring UPS performance during high capsule traffic (~150+ active capsules).
**Key Changes:**
1. **$O(1)$ Destination Failure State Guard (`scripts/hubs/hub-unpacking.lua`):** Implemented failure state tracking (`last_failed_hub`, `last_failed_hub_count`, `last_failed_hub_bar`, `last_failed_cap_count`) on capsule tracker objects inside `hub_unpacking.capture`. Instantly short-circuits slot space inspections in constant time if destination container item counts have not decreased, container bars have not expanded, and payload item counts have not dropped.
2. **Zero-Allocation Scratch Arrays (`scripts/hubs/hub-unpacking.lua`):** Replaced temporary table allocations inside `can_insert_all` with module-level flat scratch arrays (`scratch_req_names`, `scratch_req_counts`, `scratch_partial`, `scratch_filtered`), eliminating Lua garbage collection overhead during space checks. Bypassed string key concatenation for normal-quality items.
3. **Targeted Failure Cache Invalidation (`scripts/capsules/capsule-runner.lua`):** Configured `capsule_runner.wake_parked_capsules()` to clear `capsule.last_failed_hub = nil` when waking parked capsules on network edits or entity state changes, ensuring immediate unpacking re-evaluation when route space opens up.


### Revision: Circuit Proxy Lifecycle Event Fix & Visual Suppression
**Date:** 2026-08-31 08:04 (EDT)
**Context:** Fix orphaned circuit proxy constant combinators remaining after sandbox deconstruction tool usage or scripted removal, and render circuit proxy sprites invisible to eliminate visual overlap with physical entity structures.
**Key Changes:**
1. **Scripted Destruction Event Registration (`prototypes/pneumatic-pump-proxy-linkage.lua` & `prototypes/pneumatic-diverter-proxy-linkage.lua`):** Corrected `destroy_events` indexing from `defines.script_raised_destroy` to `defines.events.script_raised_destroy` in pump proxy linkage, resolving orphaned proxies during sandbox/editor instant deconstruction and scripted removals. Added Factorio 2.0 space platform build and mine event handlers (`on_space_platform_built_entity`, `on_space_platform_mined_entity`).
2. **Proxy Sprite Suppression (`prototypes/pneumatic-pump-proxy.lua` & `prototypes/pneumatic-diverter.lua`):** Configured `sprites` and `activity_led_sprites` across all four cardinal orientations to `util.empty_sprite()` on `pneumatic-pump-circuit-proxy` and `pneumatic-diverter-circuit-proxy`, rendering proxy constant combinators visually invisible while retaining full circuit wire connection and logic functionality.


### Revision: Non-Spoilable Render Polling Optimization & Factorio 2.0 Spoil API Guard
**Date:** 2026-08-31 08:23 (EDT)
**Context:** Eliminate redundant 60-tick physical container inventory scans during render overlay execution for capsules transporting non-spoilable cargo, and fix a Factorio 2.0 `LuaItemPrototype` property indexing crash during hub packing.
**Key Changes:**
1. **Spoilability Detection at Hub Packing (`scripts/hubs/hub-packing.lua`):** Implemented `is_stack_spoilable()` to safely inspect item prototypes and stacks via `get_spoil_ticks()`, `spoil_tick`, and `spoil_percent`. Evaluates cargo extractions and primary vessel stacks during packing to compute a `has_spoilable_items` flag passed to `capsule_manager.register()`.
2. **Active Capsule Spoilability Tracking (`scripts/capsules/capsule-manager.lua`):** Updated `capsule_manager.register()` to persist `has_spoilable_items` on active capsule tracker objects within `storage.active_capsules`.
3. **Guarded Render Polling & Inventory Scan Short-Circuiting (`scripts/capsules/capsule-renderer.lua`):** Refactored `render()` to suppress 60-tick periodic spoilage re-checks for non-spoilable capsules (`has_spoilable_items == false`). Updated `get_dominant_item()` to short-circuit and instantly serve cached dominant item strings without opening liminal container inventories.


### Revision: Standardized Command Naming, Shortcut Bar Toggles & Top-Level Module Loading
**Date:** 2026-08-31 08:47 (EDT)
**Context:** Clean up debug command naming consistency, add interactive toggle buttons to Factorio's shortcut bar (vertical ellipsis menu), establish bidirectional shortcut state synchronization, and enforce top-level require loading across all script modules.
**Key Changes:**
1. **Shortcut Bar Prototype Registration (`prototypes/shortcut.lua` & `data.lua`):** Registered toggleable `shortcut` prototypes (`pt-toggle-flow`, `pt-toggle-capsules`, `pt-toggle-capsule-peek`, `pt-toggle-ports`, `pt-toggle-debug`) with icon bindings and `toggleable = true` support for Factorio's shortcut bar.
2. **Standardized Command Naming & Aliases (`scripts/debug-manager.lua`):** Renamed `/capsule-peek` to `/toggle-capsule-peek` for naming alignment across all debug toggles (`/toggle-debug`, `/toggle-prints`, `/toggle-ports`, `/toggle-flow`, `/toggle-capsules`). Retained `/capsule-peek` as a backward-compatible alias alongside `pt-toggle-*` command aliases.
3. **Bidirectional Shortcut Sync & Event Handler (`scripts/debug-manager.lua` & `control.lua`):** Bound `defines.events.on_lua_shortcut` to toggle debug overlays dynamically on hotbar shortcut clicks. Implemented `debug_manager.sync_shortcuts()` with guarded `player.set_shortcut_toggled()` calls to maintain 1:1 state synchronization across GUI clicks, chat commands, and player initialization.
4. **Top-Level Module Loading Enforcement (`control.lua`):** Standardized module imports strictly to file top-levels, ensuring `debug_manager` and dependent scripts load cleanly without dynamic inline `require` calls during tick handlers or events.


### Revision: Inoperable Spilled Containers & Zero-Overhead Cleanup Engine
**Date:** 2026-08-31 09:33 (EDT)
**Context:** Prevent players from manually placing items back into spilled capsule containers by hand, eliminate tick-by-tick inventory bar enforcement loops, and restore UPS performance during network deconstructions and container spills.
**Key Changes:**
1. **Inoperable Spilled Container Prototype (`prototypes/entity.lua`):** Configured `operable = false` on the `visible-capsule-holder` prototype definition, preventing players from opening container GUIs to enforce a strict one-way spill retrieval model.
2. **Spilled Entity Lifecycle Enforcement (`scripts/hubs/hub-spill.lua`):** Updated `hub_spill.spill_capsule` to explicitly set `container_entity.operable = false` upon creation, guaranteeing non-operability across all physical surface container spills.
3. **GUI Event & Bar Scan Elimination (`scripts/hubs/hub-spill.lua`):** Removed `on_gui_opened` and `on_gui_closed` event listeners and purged tick-by-tick `set_bar(1)` GUI fighting loops. Throttled `process_spilled_containers` to evaluate empty container cleanup at a 60-tick (1-second) interval, eliminating per-tick UPS churn.


### Revision: Circuit Proxy & Shortcut Bar Toggle English Localization
**Date:** 2026-08-31 10:07 (EDT)
**Context:** Complete missing English (`en`) locale definitions for hidden constant-combinator pump circuit proxies and hotbar debug shortcuts to eliminate raw locale key fallbacks across tooltips, entity inspectors, and shortcut bar toggles.
**Key Changes:**
1. **Circuit Proxy Entity Localization (`locale/en/config.cfg`):** Added `pneumatic-pump-circuit-proxy` entry under `[entity-name]` matching `pneumatic-diverter-circuit-proxy` to ensure pump proxy combinators display clean localized entity names.
2. **Shortcut Bar Toggle Localization (`locale/en/config.cfg`):** Added `[shortcut-name]` section registering localized display names for all five hotbar toggle shortcuts (`pt-toggle-flow`, `pt-toggle-capsules`, `pt-toggle-capsule-peek`, `pt-toggle-ports`, `pt-toggle-debug`).


### Revision: Exact O(1) Biological Item Lookup Matrix & Top-Level Require Enforcement
**Date:** 2026-08-31 10:21 (EDT)
**Context:** Expand biological item support for bio capsules across all Factorio 2.0 / Space Age organic items, eliminate fuzzy string matching risks, and enforce top-level script require loading.
**Key Changes:**
1. **Strict $O(1)$ Bio Item Matrix (`scripts/capsules/capsule-definitions.lua`):** Replaced fuzzy string pattern searches (`string.find`) with an explicit lookup table (`capsule_definitions.bio_items`) containing all vanilla and Space Age organic items (`yumako`, `jellynut`, seeds, slumps, bioflux, spoilage, nutrients, eggs, bacteria, fish, wood) and the `biodegradable-capsule` item shell.
2. **Bio Slot Cost Planner Integration (`scripts/hubs/packing/cargo-planner.lua`):** Updated `cargo_planner.get_item_slot_cost()` to delegate directly to `capsule_defs.is_bio_item()`, ensuring all biological items reliably receive the `0.5` slot cost factor (2× stack capacity bonus) inside biodegradable capsules.
3. **Top-Level Module Loading Standard (`scripts/hubs/packing/cargo-planner.lua` & `scripts/hubs/hub-packing.lua`):** Enforced top-level scope for `require("scripts.capsules.capsule-definitions")` and verified strict top-level import compliance across capsule packing modules.


### Revision: Zero-Collision Circuit Proxies & Wire Selection Fix
**Date:** 2026-08-31 11:02 (EDT)
**Context:** Resolve fast-replace upgrades and building placement overlays being blocked by circuit proxy entities while preserving circuit wire network connectivity.
**Key Changes:**
1. **Empty Collision Mask (`prototypes/pneumatic-pump-proxy.lua` & `prototypes/pneumatic-diverter.lua`):** Configured `collision_mask = {layers = {}}` on proxy prototypes to eliminate all spatial collision layers, allowing fast-replace upgrades and building placement overlays to function seamlessly without proxy collision interference.
2. **Wire Selection & Flag Tuning (`prototypes/pneumatic-pump-proxy.lua` & `prototypes/pneumatic-diverter.lua`):** Removed `"not-selectable-in-game"` from `flags`, added `"no-copy-paste"`, set `selection_priority = 0`, and mapped `selection_box` to host structures, restoring red/green circuit network wire targeting.
3. **Top-Level Require Compliance (`prototypes/pneumatic-pump-proxy-linkage.lua` & `prototypes/pneumatic-diverter-proxy-linkage.lua`):** Verified strict top-level module import standards across proxy lifecycle linkage scripts.


### Revision: Zero-Overhead Circuit Proxy Selection Deferral & Visual Suppression
**Date:** 2026-08-31 11:18 (EDT)
**Context:** Prevent circuit proxy constant combinators from overriding hover selection and double-rendering selection outlines over host units (`pneumatic-pump` and `pneumatic-diverter`), while deferring GUI opening and wire targeting cleanly to the linked physical entity.
**Key Changes:**
1. **Selection Box Visual Suppression (`prototypes/pneumatic-pump-proxy.lua` & `prototypes/pneumatic-diverter.lua`):** Configured `draw_selection_box = false` on proxy prototypes to eliminate secondary green selection box outlines when mousing over host structures.
2. **Compact Selection Footprint & Priority Tuning (`prototypes/pneumatic-pump-proxy.lua` & `prototypes/pneumatic-diverter.lua`):** Reduced proxy `selection_box` to `{{-0.3, -0.3}, {0.3, 0.3}}` with `selection_priority = 0`, ensuring hovering over 90%+ of the building footprint highlights the physical unit while preserving wire connection targeting near the center.
3. **Seamless Proxy GUI Deferral (`prototypes/pneumatic-pump-proxy-linkage.lua` & `prototypes/pneumatic-diverter-proxy-linkage.lua`):** Refactored `on_gui_opened` event handlers to intercept proxy entity selection and resolve linked host entities via `surface.find_entity()`, launching host configuration GUIs (`pump_gui` / `diverter_gui`) without disruption.


### Revision: Pneumatic Control Panel GUI & Hotbar Debug Consolidation
**Date:** 2026-08-31 11:34 (EDT)
**Context:** Consolidate individual hotbar debug shortcut toggles into a unified master Pneumatic Control Panel Lua GUI frame to eliminate hotbar clutter and provide a centralized debugging interface.
**Key Changes:**
1. **Unified Control Panel GUI (`scripts/debug-manager.lua`):** Implemented `debug_manager.open_panel()`, `close_panel()`, `toggle_panel()`, and `refresh_panel()`, creating a centered, draggable frame featuring a master debug toggle, visual overlay switches (flow vectors, active capsules, hover peek, port markers), and console print toggles. Maintained mutual exclusion between active capsule rendering and hover peeking modes.
2. **Consolidated Shortcut Bar Prototype (`prototypes/shortcut.lua`):** Replaced individual shortcut bar entries with a single toggleable `pt-debug-panel` shortcut prototype, binding hotbar clicks directly to opening/closing the unified control panel.
3. **Command & GUI Event Synchronization (`scripts/debug-manager.lua` & `control.lua`):** Added `/pneumatic-panel` and `/debug-panel` console commands, updated toggle command aliases to update panel checkbox states dynamically if open, bound `on_gui_click`, `on_gui_closed`, and `on_gui_checked_state_changed` events, and enforced top-level `require` loading.
4. **Locale Expansion (`locale/en/config.cfg`):** Added `[gui-debug]` localization headers, checkbox labels, and localized name strings for the `pt-debug-panel` shortcut tooltips.


### Revision: Dynamic Spoilage Expiration Tracking & Zero-Overhead Render Polling
**Date:** 2026-08-31 12:03 (EDT)
**Context:** Dynamically update active capsule spoilability tracking when spoilable cargo completely spoils or decays during transit, eliminating perpetual 60-tick container inventory re-scans while ensuring dominant item visual icons correctly update to spoiled products.
**Key Changes:**
1. **Post-Update Spoilage Expiration Guard (`scripts/capsules/capsule-renderer.lua`):** Refactored `get_dominant_item()` to inspect active container slots using `is_stack_spoilable()`, update `cap_data.dominant_item` to the newly spoiled product (e.g. `copper-ore` or `spoilage`) first, and then flip `has_spoilable_items` to `false` only if zero spoilable stacks remain across all active slots.
2. **0-Tick Scan Suppression (`scripts/capsules/capsule-renderer.lua`):** Configured `render()` to permanently suppress 60-tick periodic inventory re-scans once `has_spoilable_items` transitions to `false`, serving cached dominant item icons directly from Lua memory in $O(1)$ time.
3. **Decoupled Lifecycle State Cleanliness (`scripts/capsules/capsule-lifecycle.lua`):** Restricted `capsule-lifecycle.lua` from performing premature state mutation on `has_spoilable_items`, preserving strict single-responsibility ownership in `capsule-renderer.lua` to prevent stale icon caching during mid-flight spoilage transitions.


### Revision: Full Item Metadata Preservation, Equipment Grid Transfer & API Guard
**Date:** 2026-08-31 14:26 (EDT)
**Context:** Resolve loss of item metadata (spoil_percent, health, durability, ammo, tags) and equipment grids (stack.grid) during capsule packing, unpacking, spilling, and refrigerated updates, and eliminate `Item is not item-with-tags` C++ runtime exceptions.
**Key Changes:**
1. **Native C++ `transfer_stack()` Engine Integration (`scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-unpacking.lua`, `scripts/hubs/hub-spill.lua`):** Updated hub extractions, disembarkation captures, and spilled container transfers to execute native `dest_slot.transfer_stack(src_stack)` calls, preserving 100% of equipment grids (`stack.grid`), installed modules, shield/energy states, spoilage, health, durability, ammo, and quality directly inside the Factorio engine.
2. **$O(1)$ Equipment Grid Copying & Restoration (`scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-unpacking.lua`, `scripts/hubs/hub-spill.lua`, `scripts/capsules/capsule-lifecycle.lua`):** Implemented `copy_equipment_grid()` to clone equipment grids (`create_grid()`) and transfer all installed equipment (`name`, `position`, `quality`, `energy`, `shield`) during fallback stack extractions and periodic 60-tick refrigerated spoilage updates.
3. **Safe Metadata Extraction & `item-with-tags` API Guard (`scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-unpacking.lua`, `scripts/hubs/hub-spill.lua`, `scripts/capsules/capsule-lifecycle.lua`):** Implemented `build_stack_spec()` to extract `spoil_percent`, `health`, `durability`, and `ammo`, strictly guarding `tags` and `custom_description` access behind `is_item_with_tags` checks to prevent Factorio `__index` crashes on standard items.


### Revision: Hub Inventory Bar Support & Targeted Diverter Capacity Expansion
**Date:** 2026-08-31 15:01 (EDT)
**Context:** Enable visual container inventory bar clamping on Pneumatic Hubs for inserter deposition control and expand internal diverter capsule capacity to eliminate single-capsule queuing bottlenecks across junctions.
**Key Changes:**
1. **Hub Prototype Inventory Bar Slider (`prototypes/entity.lua`):** Updated `inventory_type` from `"with_filters"` to `"with_filters_and_bar"` on `capsule-hub-horizontal` and `capsule-hub-vertical` prototypes, enabling the red inventory bar slider in container GUIs for inserter deposition control while retaining item slot filtering.
2. **Inserter-Independent Cargo Packing (`scripts/hubs/hub-packing.lua`):** Maintained full-container slot scanning (`#inventory`) during hub packing evaluation, ensuring pneumatic capsule extractions process any items present in red-locked slots while inserters natively respect the bar limit for item insertion into the chest.
3. **Targeted Diverter Capacity Expansion (`scripts/diverter-settings.lua` & `scripts/capsules/capsule-motion.lua`):** Added `DEFAULT_CAPACITY = 2` and `get_capacity(unit_number)` to `diverter_settings`. Updated `has_entity_network_capacity()` in `capsule-motion.lua` to dynamically query diverter capacity limits via `storage.active_diverters`, allowing up to 2 capsules to queue/transit through multi-port diverters simultaneously while preserving strict single-capsule spacing across standard tubes, pumps, and hubs.


### Revision: Dual-Tier Spatial Grid Allocation, Zero-Fuzzy Unit Detection & Water Moat Isolation
**Date:** 2026-08-31 16:02 (EDT)
**Context:** Optimize off-grid surface chunk footprint for standard cargo, isolate unit-spoilable cargo within water moat island perimeters, eliminate fuzzy string matching risks, and align container entities dead-center on tile grids.
**Key Changes:**
1. **Dual-Tier Spatial Grid Engine (`scripts/surfaces/liminal-surface.lua` & `scripts/hubs/hub-packing.lua`):** Implemented separate wide (8-tile cell spacing, $y \ge 0$) and tight (2-tile slot spacing, $y \le -100$) coordinate domains. Standard non-spoilable/non-unit cargo packs into tight slots to shrink off-grid chunk footprint by ~75%, separated from wide unit cells by a 100-tile safety buffer zone.
2. **Centered 3×3 Island Platform & Symmetrical Moat (`scripts/surfaces/liminal-surface.lua`):** Configured `paint_cell_tiles()` to construct wide cells with a spacious 3×3 `lab-dark-1` island platform surrounded by a symmetrical 2-tile thick `water` moat. Applied `+0.5` tile coordinate offsets to align container entity centers dead-center on tile grids.
3. **Zero-Fuzzy Spoilable-Unit Inspection (`scripts/hubs/hub-packing.lua`):** Implemented `is_unit_spoilable()` using Factorio 2.0 C++ prototype property checks (`proto.spoil_to_trigger_result`) and explicit table lookups (`capsule_defs.is_unit_spoilable`), completely eliminating fuzzy string searching (`string.find`).
4. **Synchronized Dual-Pool Slot Recycling (`scripts/capsules/capsule-manager.lua` & `scripts/surfaces/liminal-surface.lua`):** Persisted `is_wide` spatial domain classification on capsule tracker objects, ensuring `capsule_manager.remove()` returns freed coordinates to their respective `wide_free_slots` or `tight_free_slots` pools.


### Revision: Distinct Capsule Type Color Overlay & Valid Render Layer Z-Ordering
**Date:** 2026-08-31 16:44 (EDT)
**Context:** Resolve invalid render layer crashes during debug rendering and implement distinct color rings for each capsule prototype variant to improve network visual diagnostics.
**Key Changes:**
1. **Distinct Capsule Type Colors (`scripts/capsules/capsule-definitions.lua` & `scripts/capsules/capsule-renderer.lua`):** Configured distinct RGBA debug overlay colors for each capsule variant (`item-capsule` = Gold, `biodegradable-capsule` = Emerald Green, `refrigerated-capsule` = Frost Cyan, `spent-refrigerated-capsule` = Slate Grey, `reinforced-capsule` = Violet Purple, `player-transit-capsule` = Crimson Orange). Added `capsule_defs.get_debug_color()` with fallback protections.
2. **Valid Engine Layer Hierarchy (`scripts/networks/networks-flow-renderer.lua`, `scripts/ports/port-renderer.lua`, `scripts/capsules/capsule-renderer.lua`):** Replaced non-existent layer strings with official Factorio C++ `RenderLayer` union names (`"lower-object-above-shadow"` for flow vectors & text, `"wires-above"` for port markers, `"entity-info-icon-above"` for capsule rings/icons, and `"light-effect"` for HUD text), resolving `Unknown layer name: overlay` crashes and ensuring capsules render in front of flow maps.
3. **Dynamic Spent State Color Invalidation (`scripts/capsules/capsule-renderer.lua`):** Bound `ring_color` into `cache` equality checks in `render()`, triggering instant visual color ring updates when a refrigerated capsule expires into a spent capsule mid-flight.


### Revision: Centralized Item Transfer Handler & Full Factorio 2.0 Metadata Engine
**Date:** 2026-08-31 17:03 (EDT)
**Context:** Consolidate redundant stack extractions, fallback inventory insertions, ground spills, equipment grid copies, and metadata specification builders across hub packing, unpacking, spilling, and lifecycle modules into a centralized utility handler, guaranteeing 100% preservation of vanilla Factorio 2.0 item metadata, equipment grids (`stack.grid`), quality, spoilage, durability, health, ammo, and custom tags.
**Key Changes:**
1. **Centralized Utility Handler (`scripts/utils/item-transfer-handler.lua`):** Implemented `item_transfer_handler` exporting `copy_equipment_grid()` (clones installed equipment, positions, quality, energy, and shield levels), `build_stack_spec()` (safely extracts Factorio 2.0 stack attributes guarded behind `is_item_with_tags`), `transfer_stack()` (executes native C++ `dest_slot.transfer_stack()` first, falling back to metadata specs and grid restoration), `transfer_inventory()` (performs batched bar-bounded inventory migrations), and `spill_stack()` (handles metadata-safe ground spills with deconstruction orders).
2. **Cargo Packing & Unpacking Refactoring (`scripts/hubs/hub-packing.lua` & `scripts/hubs/hub-unpacking.lua`):** Replaced duplicated internal grid copying, stack specs, and multi-slot loops with top-level `item_transfer_handler` calls. Maintained full `#inventory` scanning during hub packing to extract cargo sitting in red-locked slots, while enforcing container insertion bar limits (`get_bar() - 1`) during hub capture unpacking.
3. **Spill Engine & Refrigerated Lifecycle Standardization (`scripts/hubs/hub-spill.lua` & `scripts/capsules/capsule-lifecycle.lua`):** Refactored container unloading and ground spills in `hub_spill` to delegate to `transfer_stack` and `spill_stack`. Standardized 60-tick refrigerated spoilage decay stack rebuilds and spent-tool conversions in `capsule_lifecycle` to utilize `build_stack_spec` and `copy_equipment_grid`.


### Revision: Fast-Looting Container Operability, Inventory Bar Clamping & GUI Suppression
**Date:** 2026-08-31 18:46 (EDT)
**Context:** Restore player Ctrl+Click fast-looting capabilities on spilled capsule containers while maintaining a strict one-way cargo retrieval model and zero-overhead periodic container cleanup.
**Key Changes:**
1. **Fast-Looting Operability & Bar Clamping (`prototypes/entity.lua` & `scripts/hubs/hub-spill.lua`):** Re-enabled `operable = true` on `visible-capsule-holder` to permit native Ctrl+Click fast entity transfer. Applied `container_inv.set_bar(1)` upon container creation, red-locking all inventory slots against manual item insertion while permitting native engine item extraction.
2. **Instant GUI Dismissal (`scripts/hubs/hub-spill.lua`):** Registered an `on_gui_opened` listener that sets `player.opened = nil` on the exact tick a spilled container is clicked, preventing access to the inventory GUI window and hiding the red bar slider.
3. **Copy-Paste & Pipette Setting Protection (`prototypes/entity.lua` & `scripts/hubs/hub-spill.lua`):** Added `"no-copy-paste"` to `visible-capsule-holder` prototype flags and registered an `on_entity_settings_pasted` listener to re-enforce `set_bar(1)` if chest settings are pasted onto a spilled container.
