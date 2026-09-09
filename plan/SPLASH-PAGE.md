# Pneumatic Tube Transport

Fast, high-throughput item and player logistics via custom pressurized pipe networks. Route specialized capsules through pneumatic tubes, control flow with multi-port diverters, and blast across your factory in personal transit capsules.

### Key Features

* **High-Performance v2 Flow Engine:** Powered by an event-driven delta wavefront architecture, the v2 engine is enabled by default. It completely eliminates building lag spikes, maintains zero-overhead (0-UPS) idle sleep, and scales active capsule capacity by 8x via discrete node hops. (Legacy v1 simulation remains available in startup mod settings during the transition period.)
* **Specialized Transit Capsules:**
  * **Standard Capsules:** Reliable baseline item transport.
  * **Biodegradable Capsules:** High-capacity single-use vessels with bonus capacity for organic cargo that dissolve automatically upon delivery.
  * **Refrigerated Capsules:** Temperature-controlled shells that drastically slow down spoilage for perishable biological cargo during transit.
  * **Reinforced Capsules:** Heavy-duty shells designed for heavy payloads.
  * **Player Transit Capsules:** Hop inside the network to travel across your factory at high speed (press `SHIFT + E` to emergency eject!).
* **Smart Flow & Port Filtering:** Route capsules using 4-port directional diverters with configurable push/pull flow modes, per-port item filters (whitelists & blacklists), and circuit network controls.
* **Hub Circuit & Item Integration:** Control container hub dispatching and receiving rules via manual toggles or red/green circuit network conditions. Cargo transfers preserve 100% of item quality, spoilage, durability, ammo, and installed equipment grids.
* **Pneumatic Control Panel & Visual Debugging:** Includes a dedicated Pneumatic Control Panel GUI (`/pneumatic-panel`) and hotbar shortcuts to toggle flow vector overlays, pressure levels, entity port markers, capsule indicator rings, and real-time Alt Mode hover-peeking.
* **Space Age Integration:** Fully integrated technology tree supporting Space Age science progression, organic cargo support, quality filtering, and space platform building compatibility.

---

### Developer Note

I vibe coded this entire mod using AI to bring the vision to life in record time. Special shoutout to [CatFireDragon](https://mods.factorio.com/user/CatFireDragon) for encouraging me to actually make this mod in the first place.

This is an early release because I wanted to get it out into the community to gather feedback. I plan to actively update the mod with more features, better balance, custom graphics, and performance optimizations. If you run into issues or have ideas, let me know!