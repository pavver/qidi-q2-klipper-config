# QIDI Q2 / Plus 4 — Optimized Klipper Configuration

This repository contains clean backups and optimized Klipper/Moonraker configuration files for the **QIDI Q2 (Plus 4)** 3D printer.

The configuration is tailored for daily, reliable printing **without a multi-material system (AMS / QIDI Box)**: it eliminates unnecessary mechanical wear, stops wasteful filament purging, speeds up calibration routines, calibrates input shaper frequencies, and bounds accelerations to safe, high-quality limits.

---

## 🛠 Key Improvements & Optimizations

### 1. Disabled Redundant Filament Cutting at Print Start (`CUT_FILAMENT_1`)
* **The Problem:** By default, stock QIDI firmware executes a mechanical filament cut using the toolhead lever before bed leveling on every print start. Without an AMS/Box, this serves no purpose: the cut stub remains inside the extruder and heatbreak, while the blade and drive mechanism suffer unnecessary wear and tear.
* **The Fix:** The `CUT_FILAMENT_1` command in the `PRINT_START` macro (`klipper-macros-qd/gcode_macro.cfg`) has been commented out.
* **Note:** Manual filament unloading via the touchscreen or macro (`M603`) continues to use the cutter as intended.

### 2. Accelerated Bed Leveling & Dual-Z Tilt Alignment (`Z_TILT` & `bed_mesh`)
Pre-print bed calibration time is cut almost in half without compromising precision:
* **Preserved Dual-Probing (`samples: 2`):** Retains two probe touches per point for maximum strain-gauge/load-cell accuracy.
* **Faster Z Lift Speed:** `lift_speed` in `[probe_air]` increased from 5 mm/s to **10 mm/s**.
* **Reduced Clearance Height:** `horizontal_move_z` lowered from 5.0 mm to **3.0 mm** (in both `[bed_mesh]` and `[z_tilt]`), cutting vertical travel time between points.
* **Faster Travel Speeds:** XY travel speed (`speed`) between mesh points increased from 100/150 mm/s to **250 mm/s**.
* **Eliminated Redundant Homing:** Replaced unconditional `G28` in `G29` with conditional homing `_CG28`. The printer no longer wastes 15 seconds re-homing axes during print start.
* **Removed Artificial Delays:** Removed arbitrary hardcoded pauses `G4 P3000` (3s) and `G4 P5000` (5s).

### 3. Nozzle Cleaning Without Purging ("No-Poop" mod in `CLEAR_NOZZLE`)
* **The Problem:** Before wiping the nozzle on the silicone brush, stock firmware flushed 85 mm of filament into the rear purge chute on every single print. For single-color printing, this creates heaps of plastic waste, fouls the silicone brush with molten blobs, and wastes time.
* **The Fix:** Commented out extrusion and retraction lines (`G1 E5`, `G1 E80`, `G1 E-2`) in `CLEAR_NOZZLE`.
* **How Wiping Works Now:** The nozzle heats over the chute to soften any old filament residue, activates the part cooling fan at 100%, and cools down to 140°C while actively scrubbing across the silicone brush and scraper. The nozzle tip lands on the bed completely clean, rigid, and cold for accurate load-cell probing, while extruder priming is handled by the standard purge line on the build plate right before the model begins.

### 4. Interactive Bed Screw Tramming Assistant (`SCREWS_TILT_CALCULATE`)
* **Feature:** Added `[screws_tilt_adjust]` with CW-M4 threads mapped directly to the 4 bed leveling thumb screws.
* **Ukrainian Guidance:** Added custom macro wrapper that prints clear Ukrainian instructions directly to the console:
  * `CW` = Turn clockwise (right ↻)
  * `CCW` = Turn counter-clockwise (left ↺)
  * Clock minutes (e.g. `00:15`) = Quarter turn (15 minutes on a clock face)
* Lets you mechanically level the bed plate in under 2 minutes.

### 5. Completion Sound Notification (`BEEP`)
* Replaced sluggish double-beep with 3 crisp, distinct beeps (`BEEP I=3 DUR=200`) in `PRINT_END` so you immediately know when your print has completed.

### 6. Smoother Camera Streaming (30 FPS)
* Raised camera framerate in `crowsnest.conf` from 15 FPS to **30 FPS**, taking full advantage of the hardware MJPG encoder on the internal camera for much smoother live video streaming in Fluidd/Mainsail.

### 7. Calibrated Input Shaper & Realistic Acceleration Limits
* **Measured Frequencies (LIS2DW Accelerometer):**
  * X axis: `shaper_type_x = ei`, `shaper_freq_x = 43.8 Hz` (residual vibrations ~6.2%).
  * Y axis: `shaper_type_y = mzv`, `shaper_freq_y = 47.8 Hz` (residual vibrations **0.2%**).
* **Safe Acceleration Limits:**
  * Lowered theoretical `max_accel` from 20,000 mm/s² down to a realistic **6,000 mm/s²** in `[printer]`.
  * Lowered macro defaults in `PRINT_START`, `PAUSE`, `RESUME`, `CANCEL_PRINT` from 10,000 to **5,000 mm/s²**.
  * Added auto-clamping in `M204` to prevent slicer commands from exceeding `max_accel`, eliminating corner rounding and motor jerking.

---

## 📂 Repository Structure

* `printer.cfg` — Main Klipper configuration (kinematics, TMC stepper drivers, axis limits, `probe_air` sensor, `[bed_mesh]`, `[z_tilt]`, and `[screws_tilt_adjust]`).
* `klipper-macros-qd/gcode_macro.cfg` — Core QIDI macros (`PRINT_START`, `CLEAR_NOZZLE`, `G29`, `SCREWS_TILT_CALCULATE`, `PRINT_END`, etc.).
* `klipper-macros-qd/KAMP_Settings.cfg` — KAMP adaptive mesh configuration.
* `moonraker.conf` — Moonraker API server configuration.
* `MCU_ID.cfg` — Toolhead and mainboard MCU serial IDs.
* `crowsnest.conf`, `timelapse.cfg` — Webcam streaming (30 FPS) and timelapse settings.
