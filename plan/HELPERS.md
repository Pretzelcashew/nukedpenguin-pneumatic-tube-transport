Regex cite brackets remover

\s*\[cite[^\]]*\]





Now make me a revision code block based on the changes we just made. 
The output must be in a code block I can press copy on here.

I have provided a sample of previous revisions to give you an idea of the format:

### Revision: Electric Energy Interface Fix & Instant Power-State Sensitivity `[INCORPORATED IN TABLE]`
**Context:** Resolve 0 W power consumption display and false unpowered network recalculations caused by energy buffer depletion mid-frame during entity destruction events.
**Key Changes:**
1. **Energy Source Buffer Tuning (`prototypes/entity.lua`):** Configured `buffer_capacity` to `3kJ` and `input_flow_limit` to `60kW` on the `pneumatic-pump` prototype. This provides necessary headroom so `entity.energy` remains above zero during mid-frame event checks while maintaining sub-0.1s network shutdown response times upon true grid disconnection.
2. **Sprite Table Correction (`prototypes/entity.lua`):** Updated `pneumatic-pump` prototype definition to use the plural `pictures` table required by `electric-energy-interface` entities.
3. **Power-State Polling & Invalidation (`scripts/networks/pump-manager.lua`):** Implemented a periodic `on_tick` scanner (15-tick interval) tracking `active_pumps` and `pump_power_states`. Power toggles automatically trigger `networks_flow.build(net_id)` to re-evaluate pressure and flow vectors across connected subgraphs.

### Revision: Hub Operational Mode Toggles (`can_send` / `can_receive`) & Relative GUI Integration
**Context:** Add configurable operational mode toggles to Hub GUIs, allowing players to restrict hubs to send-only (dispatch), receive-only (arrival), or bidirectional operation without altering physical pressure or network flow vectors.
**Key Changes:**
1. **Persistent Hub Settings Storage (`control.lua`, `hub-manager.lua`):** Initialized `storage.hub_settings` schema to store per-entity boolean toggles (`can_send`, `can_receive` defaulting to `true`). Added automatic entry provisioning on build (`on_hub_built`) and cleanup on entity destruction (`on_hub_removed`).
2. **Relative GUI Anchor & Event Synchronization (`hub-manager.lua`):** Integrated a custom UI panel anchored relative to open hub chest windows using `defines.relative_gui_type.container_gui` and `defines.relative_gui_position.right`. Registered event listeners for `on_gui_opened`, `on_gui_closed`, and `on_gui_checked_state_changed` to dynamically instantiate UI elements and sync toggle state changes.
3. **Dispatch Permission Gating (`hub-packing.lua`):** Integrated an early evaluation guard in `hub_packing.evaluate_inventory()` checking `storage.hub_settings[unit_number].can_send`. If `false`, inventory packing and runner injection are aborted before container item extraction.
4. **Arrival Permission Gating (`hub-unpacking.lua`):** Integrated a capture guard in `hub_unpacking.capture()` checking `storage.hub_settings[unit_number].can_receive`. If `false`, capsule capture and liminal holder inventory transfer are rejected, leaving incoming capsules safely parked upstream on destination entity ports.




Now make a commit title for git in vs code

Avoid using [cite] blocks

Include today's date YYYY-MM-DD HH:MM (EDT/EST)






Please sync our documentation with the latest changelog updates by following these steps:

1. **Update Architecture:** Modify `architecture.md` to fully reflect all unapplied changes listed in `changelog.md` (specifically, any items not yet marked as incorporated in the changelog table).
2. **Mark as Applied:** Update `changelog.md` to clearly mark all of those newly processed items as applied/incorporated.
3. **Output Format:** Provide the full, updated contents of both `architecture.md` and `changelog.md` in full, ready for me to copy and paste.