# QIDI Q2 — Optimized Klipper Configuration

Klipper/Moonraker configuration for the **QIDI Q2** 3D printer (270×270 mm bed), tuned for daily single-spool printing **without a QIDI Box**: no filament cutting and purging at every print start, faster bed leveling, sane acceleration limits and a few quality-of-life helpers.

All changes live in one file, [`custom_overrides.cfg`](custom_overrides.cfg), on top of the **unchanged stock QIDI config**. Because of that, QIDI's own macros and multi-color logic keep working.

> [!IMPORTANT]
> **Tested on firmware `QD_Q2_01.01.03.02`** (SOC build `01.01.03.02_20261023`).
>
> On a **newer firmware**, do not just copy the files. QIDI changes stock macros between releases, and `custom_overrides.cfg` contains full copies of four of them (`PRINT_START`, `CLEAR_NOZZLE`, `PRINT_END`, `G29`). First compare your new stock `gcode_macro.cfg` with [`stock/01.01.03.02/`](stock/01.01.03.02/) (see [After a firmware update](#-after-a-firmware-update)).
>
> This config is **not** for the QIDI Plus 4 (different bed size and axis limits).

---

## 🧱 How This Config Works (and Why It Changed)

**Before (up to commit `87ebbd9`):** the tweaks were made directly inside the stock files `printer.cfg` and `klipper-macros-qd/gcode_macro.cfg`. You installed the config by replacing these files with the modified copies from this repository.

**Now:** the stock files stay **unchanged**. All tweaks live in a separate file, `custom_overrides.cfg`, which is connected with one line at the end of `printer.cfg`:

```ini
[include custom_overrides.cfg]
```

Klipper reads the config from top to bottom, and **a later definition wins**. A section such as `[printer]` or `[bed_mesh]` that is defined again in `custom_overrides.cfg` overrides only the options listed there. A `[gcode_macro ...]` defined there replaces the stock macro with the same name. Everything else comes from the stock files as-is.

**Why the change:**

1. **Firmware updates overwrite the config.** Updating to `QD_Q2_01.01.03.02` silently replaced `printer.cfg`, `gcode_macro.cfg` and `crowsnest.conf` with new stock versions. All tweaks were lost, and the printer quietly went back to stock behavior: filament cutting, chute purge, `max_accel` 20,000.
2. **The old modified files break new firmware.** The new stock files contain things the old copies do not have: macros `T0`–`T15`, `TRY_INTO_EXTRUDER`, `DROP_TRASH`, `_km_beep_if_available`, a new `G28` wrapper, and the `[box485]`/`[box2base]` sections. QIDI's closed-source modules call some of them. Copying the old modified files over a new firmware deletes them, which can break filament loading and multi-color printing with a QIDI Box.
3. **The tweaks are easy to see and to undo.** All of them sit in one file, and edits inside copied macros are marked `[custom]`. Removing the `[include ...]` line returns the printer to pure stock.
4. **Updates are easier to check.** [`stock/01.01.03.02/`](stock/01.01.03.02/) keeps the untouched stock config folder of that firmware. After the next firmware update, a new `stock/<version>/` folder is added next to it, and one `diff` shows what QIDI changed and whether `custom_overrides.cfg` needs updating.

The repository root therefore contains **only own files** (`custom_overrides.cfg`, `fixes/`). Everything that comes from QIDI lives in `stock/<firmware version>/`.

**If you installed an older version of this repository:** do not put the old modified `printer.cfg` / `gcode_macro.cfg` back. Keep the stock files that your current firmware installed, then follow [Installation](#-installation). If you are still on an older firmware than `01.01.03.02`, note that `custom_overrides.cfg` was made from the `01.01.03.02` stock macros. It has not been tested there.

---

## 🛠 What Is Changed

Everything below lives in `custom_overrides.cfg`. Edits inside copied stock macros are marked `[custom]`.

### 1. No Filament Cutting at Print Start (`CUT_FILAMENT_1`)
* **Stock:** every print starts with a mechanical filament cut before leveling. Without a Box this is pointless: the cut stub stays in the extruder, and the blade wears out.
* **Now:** `PRINT_START` calls `CUT_FILAMENT_1` only when the QIDI Box is enabled (`enable_box = 1`).
* Unloading filament from the screen (`M603`) still uses the cutter, as it should.

### 2. No Purge Into the Chute ("No-Poop" `CLEAR_NOZZLE`)
* **Stock:** 85 mm of filament is pushed into the rear chute before every print.
* **Now:** the purge happens only when the Box is enabled. Without the Box, the nozzle is heated, then cooled to 140 °C while it is wiped on the silicone brush. It reaches the bed clean and cold for accurate load-cell probing.
* ⚠️ **The nozzle is then primed only by the purge line in your slicer's start G-code.** Keep it in the slicer profile. After a manual color change, expect a bit of the old color at the start of the print.

### 3. Faster Bed Leveling
* `[z_tilt]` and `[bed_mesh]`: travel speed **250 mm/s** (stock 150/100), `horizontal_move_z` **3 mm** (stock 5).
* `[probe_air]`: `lift_speed` **10 mm/s** (stock 5). Dual probing (`samples: 2`) is kept.
* `G29`: homes only if not homed yet (`_CG28` instead of `G28`), and two 5 s pauses are removed.
* `PRINT_START`: the 3 s pause before `G29` is removed, since `M190`/`M191` already wait for temperatures.
* If the Klipper log shows many `samples_tolerance` retries, the strain-gauge probe needs more settling time. Restore the pause in that case.

### 4. Acceleration Limits and a Fixed `M204`
* `[printer] max_accel` lowered from the theoretical **20,000** to **6,000 mm/s²**.
* `M204` is clamped to `max_accel`. Stock macros and slicers ask for up to 10,000 mm/s², and plain Klipper would accept it above the limit. The clamp is why the stock `M204 S10000` calls in `PRINT_START`, `PAUSE`, `CANCEL_PRINT` and so on no longer need edits.
* Also fixes stock `M204` crashing on `M204 P<n>` without `T` (Marlin-flavor slicer output) and on a plain `M204`.
* **Re-run `SHAPER_CALIBRATE` after a firmware update.** The update resets input shaper to factory values. Keep `max_accel` at or below the lower of the two "suggested max_accel" values it reports. For reference, this printer measured `ei` 43.8 Hz on X and `mzv` 47.8 Hz on Y before the update.

### 5. Bed Screw Tramming Assistant (`SCREWS_TILT_CALCULATE`)
* `[screws_tilt_adjust]` for the 4 bed screws (CW-M4).
* A wrapper prints instructions in Ukrainian: `CW` turn clockwise ↻, `CCW` turn counter-clockwise ↺, `00:15` is a quarter turn.

### 6. Completion Beep
* `PRINT_END` gives 3 short beeps (`BEEP I=3 DUR=200`) instead of 2 long ones.

### 7. Camera at 30 FPS
* `crowsnest.conf`: `max_fps` raised from 15 to **30**. This is the only change outside `custom_overrides.cfg`, because crowsnest has no include mechanism. It is a one-line manual edit (see [Installation](#-installation)).

### 🧩 Using It With a QIDI Box
The changes that matter for multi-color printing (filament cut, chute purge) check `enable_box` and keep the stock behavior when the Box is enabled. Faster leveling, `max_accel` and `M204` apply to everybody. This config was tested **without** a Box. If you use a Box, check one multi-color print before relying on it.

### Pressure Advance
Not overridden. QIDI changed the stock value from 0.045 to 0.032 in `01.01.03.02`. It is better to calibrate pressure advance per filament and set it in the slicer's filament profile.

---

## 📥 Installation

Work on an idle printer (not printing). Fluidd: `http://<printer-ip>` → **Configuration**.

1. **Back up** your current `printer.cfg` and `crowsnest.conf` (download them in Fluidd).
2. **Upload** [`custom_overrides.cfg`](custom_overrides.cfg) to the config folder, next to `printer.cfg`.
3. **Add one line** at the end of your `printer.cfg`, right **before** the `#*# <---------------------- SAVE_CONFIG` block. It must come after all other `[include ...]` lines:
   ```ini
   [include custom_overrides.cfg]
   ```
4. In `crowsnest.conf` set `max_fps: 30` (optional).
5. Click **Save & Restart**, or send `FIRMWARE_RESTART`.

Edit **your own** `printer.cfg`, do not replace it with `stock/01.01.03.02/printer.cfg`. The `#*# SAVE_CONFIG` block at the end of every `printer.cfg` (input shaper, bed meshes, probe offset) is calibrated for one specific printer. The stock copy in this repository contains the factory values of the author's printer.

**To undo:** remove the `[include custom_overrides.cfg]` line and restart.

---

## 🔄 After a Firmware Update

A QIDI firmware update **overwrites `printer.cfg`, `gcode_macro.cfg` and `crowsnest.conf`** and resets input shaper and bed meshes. Your tweaks are silently gone, and the printer runs stock settings again.

1. Before changing anything, download the whole config folder from the printer (Fluidd → Configuration). Save it into this repository as `stock/<new version>/`, for example `stock/01.01.04.01/`. Leave out `MCU_ID.cfg`, `saved_variables.cfg` and backup files: they are printer-specific state, not stock files.
2. Compare it with the previous stock version:
   ```bash
   diff -ru --strip-trailing-cr stock/01.01.03.02/ stock/<new version>/
   ```
   * If `PRINT_START`, `CLEAR_NOZZLE`, `PRINT_END` or `G29` changed, port QIDI's changes into `custom_overrides.cfg`. Otherwise this file would hide them.
   * If nothing relevant changed, you only need to re-add the `[include custom_overrides.cfg]` line.
3. Re-run `SHAPER_CALIBRATE` and bed meshing.
4. Check whether the [filament loading fix](#-firmware-bug-fix-filament-loading-hangs-at-step-2) is still needed. Put fixes for the new firmware into a new `fixes/<new version>/` folder.

---

## 📋 What QIDI Changed in `01.01.03.02` (vs `01.01.02.04`)

Found by comparing [`stock/01.01.02.04/`](stock/01.01.02.04/) and [`stock/01.01.03.02/`](stock/01.01.03.02/). Only `printer.cfg` and `klipper-macros-qd/gcode_macro.cfg` changed. All other stock files are identical.

**`printer.cfg`:**
* New sections `[box485]` (RS485 link to the QIDI Box) and `[box2base]`.
* `pressure_advance`: 0.045 → **0.032**.
* Filament runout: `AUTO_RELOAD_FILAMENT` no longer checks `printer["box_extras"]`.

**`gcode_macro.cfg`:**
* New `G28` wrapper with `LAZY_HOME` (Marlin-style `G28 O` skips already homed axes). Homing macros now call the renamed original `G28.6245197`.
* `[homing_override]`: `axes: xy` → `xyz`. The `X+Y` homing path was reworked.
* `PRINTER_INIT` calls `INIT_RFID_READ` at startup.
* `RESUME`: the stock filament / Box checks were replaced by a single `TRY_RESUME_PRINT` call.
* `M604` (filament load) turns off the fan and heater at the end.
* New macros: `T0`–`T15` (`T_MANAGER`), `TRY_INTO_EXTRUDER`, `MOVE_ANOTHER_POINT_CHANGE_FILAMENT`, `DROP_TRASH`, `WIPE_NOZZLE_DROP`, `_km_beep_if_available`.
* `PRINT_START`, `CLEAR_NOZZLE`, `PRINT_END` and `G29` did **not** change, so the copies in `custom_overrides.cfg` match both versions.

Also new in this firmware, outside the config: the [filament loading bug](#-firmware-bug-fix-filament-loading-hangs-at-step-2).

---

## 🐞 Firmware Bug Fix: Filament Loading Hangs at Step 2

> [!WARNING]
> **If you updated to firmware `QD_Q2_01.01.03.02` and filament loading gets stuck at step 2, with this error in the Fluidd/Mainsail console:**
> ```
> !! Unable to parse 'slot16' as a literal
> ```
> **run [`fixes/01.01.03.02/fix_save_variable_unquoted.sh`](fixes/01.01.03.02/fix_save_variable_unquoted.sh) on the printer (see "How to apply" below). It fixes the problem.**
>
> The script is **not** applied by installing this config. You have to run it manually once.

* **Affected firmware:** `QD_Q2_01.01.03.02` (SOC build `01.01.03.02_20261023`). Filament loading worked fine on the previous version `01.01.02.04`. You can check your version on the printer screen or in `/home/qidi/update/` (`QD_Q2_SOC_*` file name).
* **The Problem:** Loading filament from the touchscreen heats the nozzle, then gets stuck on step 2. The closed-source `multi_color_controller` sends `SAVE_VARIABLE ... VALUE=slot16` without quotes. Stock `save_variables.py` rejects it, so the loading flow aborts and resets itself.
* **The Fix:** The script patches `/home/qidi/klipper/klippy/extras/save_variables.py` so that values which cannot be parsed are stored as plain strings instead of raising an error.
* **Safe with a QIDI Box:** Only values that used to fail are affected. Numbers, quoted strings, `True`/`False` and lists are parsed exactly as before.
* **Safety checks:** The script refuses to run while printing, makes a backup (`save_variables.py.orig`), and stops without touching anything if your firmware's code differs from the expected one.
* **How to apply** (this file lives outside the config folder, so it needs SSH):
  * **Default SSH credentials:** login `mks`, password `makerbase`. The `mks` user can run `sudo` with the same password, which the script needs.
  * `<printer-ip>` is the printer's IP address (shown on the printer screen under network settings), or its hostname if you have one set up (e.g. `klipper.local`).
  ```bash
  scp fixes/01.01.03.02/fix_save_variable_unquoted.sh mks@<printer-ip>:/tmp/
  ssh mks@<printer-ip>
  bash /tmp/fix_save_variable_unquoted.sh            # apply
  bash /tmp/fix_save_variable_unquoted.sh --revert   # undo
  ```
  The script restarts the `klipper` service (`FIRMWARE_RESTART` does not reload Python modules).
* **Note:** A firmware update may overwrite the file. If the error returns, run the script again.

---

## 📂 Repository Structure

**Own files (root):**
* `custom_overrides.cfg` — **all tweaks**. Upload it next to `printer.cfg` and include it at the end of `printer.cfg`.
* `fixes/<firmware version>/` — fixes for bugs of a specific firmware version. Each fix lives in the folder of the firmware it was made and tested for. Do not run it on other versions without checking.
  * `fixes/01.01.03.02/fix_save_variable_unquoted.sh` — patch for the "Unable to parse 'slot16' as a literal" filament loading bug (run on the printer via SSH).

**Stock QIDI files (`stock/<firmware version>/`):**
* [`stock/01.01.02.04/`](stock/01.01.02.04/) — the same for the previous firmware `QD_Q2_01.01.02.04`. Taken from the first backup of this printer, before any tweaks.
* [`stock/01.01.03.02/`](stock/01.01.03.02/) — the complete, untouched config folder installed by firmware `QD_Q2_01.01.03.02`: `printer.cfg`, `klipper-macros-qd/`, `KAMP/`, `crowsnest.conf`, `timelapse.cfg`, `moonraker.conf`, … Used as a reference for comparing after firmware updates. Do not copy it to the printer as-is. `printer.cfg` there contains the author's factory `SAVE_CONFIG` block, and `MCU_ID.cfg` (MCU serial IDs) is deliberately not stored, because it is unique to each printer.
