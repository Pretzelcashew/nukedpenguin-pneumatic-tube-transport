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