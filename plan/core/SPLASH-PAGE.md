# Pneumatic Tube Transport

Move items and players across your factory through pressurized tube networks. Build pipe lines, set up diverter junctions with item and quality filters, launch capsules through the air with electromagnetic projectors, and read network traffic with capsule counters.

---

### What's New in 0.3.21
* **Electromagnetic Projector (Fulgora):** Launch Electromagnetic Capsules across open air directly into remote receiving projectors up to 500 tiles away.
* **Capacitor Firing Cadence:** Projectors require 9 MJ stored power per shot and pause automatically if the destination dock is backed up.
* **Flight Hazards:** Don't stand in the beam path—flying projectiles deal impact damage to players and vehicles on collision.
* **Planetary Recipe Requirements:** Specialized capsules now require their matching Space Age planetary environments to craft (Vacuum on platforms, Reinforced on Vulcanus, Refrigerated on Aquilo, and Electromagnetic on Fulgora).

---

### How It Works

1. **Build Tubes & Hubs:** Place Pneumatic Tubes between Pneumatic Hubs. Hubs pack items from chests into capsules and inject them into the network.
2. **Pressurize the Line:** Place Pneumatic Pumps along the line to push air forward (+ pressure) or draw a vacuum (- pressure). Capsules naturally move from higher pressure to lower pressure.
3. **Route Traffic:** Use 4-way Diverters to split, merge, or filter capsules by item type and quality.
4. **Unpack at Destinations:** Destination hubs automatically catch capsules, pull the cargo out into their inventory, and handle empty hulls.

---

### Capsule Types

* **Standard Capsule:** Basic multi-stack freight capsule.
* **Biodegradable Capsule (Gleba):** Cheap organic capsule made from yumako mash, jelly, and spoilage. Carries cargo once and dissolves completely on delivery.
* **Refrigerated Capsule (Aquilo):** Slows spoilage on perishable food/bio cargo by 90% while in transit. Reusable and recharged with fluoroketone.
* **Reinforced Capsule (Vulcanus):** Heavy-duty capsule for bulk single-item transport (2 full stacks base).
* **Electromagnetic Capsule (Fulgora):** Carries mixed cargo, partial stacks, and mixed qualities. Can be launched through the air by Electromagnetic Projectors.
* **Vacuum Capsule (Space Science):** Interacts with transport belts. Automatically sucks items off belts under negative pressure and spits items out onto belts under positive pressure.
* **Player Transit Capsule:** Lets you hop into the tube network to travel across your factory quickly. Press `SHIFT + E` to emergency eject anywhere.

---

### Network Devices

* **Pneumatic Hubs:** Entrance and exit points for cargo. Connect to chests or belts to pack and unpack capsules.
* **Pneumatic Pump:** Generates directional pressure to drive capsule movement. Supports circuit network enable conditions.
* **Pneumatic Diverter:** 4-port junction with configurable routing. Filter each port by item, quality, or blacklists using native Factorio 2.0 comparison rules (`=`, `≥`, `≤`, `>`, `<`, `≠`, or Any Quality).
* **Capsule Counter:** Placed along tubes to read passing capsules or cargo contents onto the circuit network. Outputs to Red and Green wires independently without signal cross-talk.
* **Electromagnetic Projector:** A 3x3 launcher that shoots Electromagnetic Capsules through the air across long distances without needing continuous tube lines.
* **Wall & Gate Integration:** Research fence-gate interop to route pneumatic tubes directly through vanilla stone walls and gates. Gates automatically shut off transit when opened and restore flow when closed.

---

### Controls & Hotkeys

* `SHIFT + E`: Emergency exit from a riding transit capsule.
* `SHIFT + Right-Click / Left-Click`: Copy and paste settings between Hubs, Diverters, Pumps, and Projectors (works on ghosts too).
* `ALT Mode`: Displays pressure values, flow directions, diverter filter icons, and projector launch paths directly in the world.

---

### Note on Development

I built this mod using AI assistance to turn the concept into working code quickly. Big thanks to [CatFireDragon](https://mods.factorio.com/user/CatFireDragon) for the initial encouragement to get this built.

Feedback, balance suggestions, and bug reports are welcome on the mod portal!