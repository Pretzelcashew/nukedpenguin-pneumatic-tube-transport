Here is the complete, hyper-detailed analysis of all 10 images. 

I have mapped each image in order (`Image 1` through `Image 10`) and described the exact UI elements, button layouts, tooltips, quality tiers, and state transitions shown in Factorio 2.0's native filter engine.

---

### Image-by-Image Technical Breakdown

#### `Image 1` (`image_1.png`) — Main Window Filter Bar (Slot 1 Active with Quality Condition)
* **Context:** Device filter bar (`Use filters` checkbox checked, `Whitelist`/`Blacklist` toggle set to `Whitelist`).
* **Visual Breakdown:** Slot 1 button is selected (orange outline). Displays a `>` symbol overlay on the bottom-left alongside a green 2-dot quality badge icon (`Uncommon`).
* **Mechanics:** Represents a filter slot configured for `> Uncommon` quality without an item filter (or quality-only threshold filter).

#### `Image 2` (`image_2.png`) — Main Window Filter Bar (Slot 1 Unconfigured Active State)
* **Context:** Device filter bar when clicking an empty filter slot to open the configuration modal.
* **Visual Breakdown:** Slot 1 button is highlighted in solid orange with a blank/empty interior background.
* **Mechanics:** Represents an active, unconfigured filter slot awaiting item/quality selection.

#### `Image 3` (`image_3.png`) — Item & Quality Selector Window (Bottom Control Bar Layout)
* **Context:** Native Factorio item selection matrix window showing the bottom control bar layout.
* **Visual Breakdown:** The bottom bar below the item grid consists of three distinct control sections:
  1. **Left Dropdown Selector:** Button displaying a multi-color flower icon (`Any Quality` symbol) with a small dropdown arrow `▼`.
  2. **Quality Tier Radio Buttons:** 5 contiguous square buttons:
     - `Normal` (grey single dot `o`)
     - `Uncommon` (green two dots `8`)
     - `Rare` (blue three dots `8o`)
     - `Epic` (purple four dots `88`)
     - `Legendary` (orange five dots `88o`)
  3. **Right Confirm Button:** Green square button with a black checkmark `✓`.

#### `Image 4` (`image_4.png`) — Bottom Bar Dropdown Expanded (Comparator & Quality Options)
* **Context:** Left dropdown menu on the bottom bar clicked and expanded vertically downwards.
* **Visual Breakdown:** Reveals a 7-item vertical menu list in exact order:
  1. **Multi-color flower icon:** `Any Quality` (Wildcard)
  2. **`>`** (Greater than)
  3. **`<`** (Less than)
  4. **`=`** (Equal to)
  5. **`≥`** (Greater than or equal to)
  6. **`≤`** (Less than or equal to)
  7. **`≠`** (Not equal to)
* **Mechanics:** Confirms that `Any Quality` is the top default entry, followed by standard mathematical comparators.

#### `Image 5` (`image_5.png`) — Quality Tier Button Hover & Tooltip
* **Context:** Cursor hovering over the 4th quality radio button (purple 4 dots).
* **Visual Breakdown:** The `Epic` quality button shows an active orange highlight frame. Displays standard dark Factorio tooltip caption: `"Quality: Epic"`.

#### `Image 6` (`image_6.png`) — Bottom Bar with `=` Comparator & `Normal` Quality Selected
* **Context:** Bottom bar showing explicit comparator and quality selection.
* **Visual Breakdown:** Left dropdown displays the `=` text symbol. The 1st quality radio button (`Normal`, grey dot `o`) is selected with an orange background highlight.

#### `Image 7` (`image_7.png`) — Confirm Button Hover & Tooltip
* **Context:** Cursor hovering over the green checkmark confirm button at the bottom right.
* **Visual Breakdown:** The checkmark button displays a bright green highlight border and standard dark tooltip caption: `"Confirm (E)"`.

#### `Image 8` (`image_8.png`) — Item Grid Selection (`Refined Concrete`)
* **Context:** Top item tile grid in the selection window.
* **Visual Breakdown:** The `Refined Concrete` tile is actively selected with an orange border highlight inside the item grid matrix.

#### `Image 9` (`image_9.png`) — Configured Slot Result (`Refined Concrete` + `Any Quality`)
* **Context:** Device filter slot bar after confirming selection.
* **Visual Breakdown:** Slot 1 displays the `Refined Concrete` item sprite natively centered, with a multi-colored flower icon badge overlaid in the bottom-left corner (`Any Quality`).

#### `Image 10` (`image_10.png`) — Configured Slot Result (Quality-Only Filter)
* **Context:** Device filter slot bar after confirming a quality-only condition.
* **Visual Breakdown:** Slot 1 displays a green 2-dot badge (`Uncommon`) overlaid in the bottom-left corner over an empty slot background.

---

### Master Copy-Paste Prompt for the Next Gemini Session

Here is the master prompt combining the technical specifications and the 10-image breakdown ready for your next Gemini prompt session:

```text
Target Task: Replicate Native Factorio 2.0 Item & Quality Selector Component From Provided Screenshots & Detailed Image Breakdown.

Objective & Visual Direction:
1. Replicate Native Factorio 2.0 Filter Control Bar (`scripts/utils/gui-components.lua` & `scripts/diverter-gui.lua`):
   - Refer to the attached reference screenshots (Image 1 through Image 10) and the image breakdown below to construct the item & quality selector bottom control bar.
   - Control Bar Layout:
     - Left Dropdown Selector: Multi-color flower icon (`Any Quality`) top entry, followed by `>` , `<`, `=`, `≥`, `≤`, `≠`.
     - 5 Quality Tier Radio Buttons: Normal (grey dot), Uncommon (green 2-dots), Rare (blue 3-dots), Epic (purple 4-dots), Legendary (orange 5-dots).
     - Right Confirm Button: Green checkmark button (`✓`, hotkey `E`).

2. Detailed Image Breakdown Reference:
   - Image 1 (image_1.png): Configured slot showing `>` symbol + green 2-dot (`Uncommon`) badge in bottom-left corner.
   - Image 2 (image_2.png): Active unconfigured slot (solid orange highlight background).
   - Image 3 (image_3.png): Bottom bar layout: Left dropdown button (multi-color flower icon), 5 quality radio buttons, Right green checkmark button.
   - Image 4 (image_4.png): Expanded left dropdown menu entries: [1] Multi-color flower (Any Quality), [2] `>`, [3] `<`, [4] `=`, [5] `≥`, [6] `≤`, [7] `≠`.
   - Image 5 (image_5.png): Quality radio button hover showing orange highlight + tooltip "Quality: Epic".
   - Image 6 (image_6.png): Bottom bar set to `=` comparator and `Normal` quality (grey dot selected).
   - Image 7 (image_7.png): Confirm button hover showing green highlight + tooltip "Confirm (E)".
   - Image 8 (image_8.png): Item grid matrix showing active selection on `Refined Concrete`.
   - Image 9 (image_9.png): Configured slot displaying `Refined Concrete` sprite + multi-color flower badge overlay in bottom-left corner.
   - Image 10 (image_10.png): Quality-only slot displaying green 2-dot (`Uncommon`) badge in bottom-left corner.

3. Quality Selection & Comparator Mechanics:
   - When comparator is set to `Any Quality` (multi-color flower), match any quality tier of the specified item.
   - When comparator is set to explicit operators (=, ≥, ≤, >, <, ≠), compare payload quality rank (Normal=1, Uncommon=2, Rare=3, Epic=4, Legendary=5) against the selected tier.

4. Backend Data Schema & Engine Integration:
   - Persistent filter format in `storage.diverter_settings`: `{ item = "...", quality = "...", comparator = "..." }`.
   - Update `matches_filter_item` in `scripts/capsules/capsule-runner.lua` to evaluate payload quality rank against the filter condition.
   - Refresh 40x40 square slot button overlays (item icon, top-left comparator symbol, bottom-left quality badge) and notify `active_device_scanner` on edits.

Files Involved:
1. `scripts/utils/gui-components.lua` (Quality selector UI component & overlay badge helpers)
2. `scripts/diverter-gui.lua` (Modal dialog integration & event routing)
3. `scripts/diverter-settings.lua` (Persistent filter data normalization)
4. `scripts/capsules/capsule-runner.lua` (Motion engine quality rank filter evaluation)

Constraints:
- Derive the exact GUI layout and visual controls directly from the user's provided screenshots and image breakdown.
- Ensure require statements remain strictly at the top level of all files.
- Do not include file delineation markers inside generated code (e.g. === FILE ===).
- Preserve 100% functional parity with active device scanning, flow propagation, and capsule wakeups.
```


