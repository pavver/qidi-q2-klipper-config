#!/bin/bash
# Fix for QIDI Q2 firmware QD_Q2_01.01.03.02: filament loading hangs at
# step 2 with
#   "!! Unable to parse 'slot16' as a literal"
#
# This script is NOT run automatically. Run it manually once on the printer
# only if you see the error above.
#
# The closed-source multi_color_controller sends SAVE_VARIABLE with an
# unquoted string value (VALUE=slot16). Stock Klipper rejects it, the loading
# flow aborts and resets. This patch makes SAVE_VARIABLE store such values as
# plain strings instead of failing. Values that were valid before (numbers,
# quoted strings, True/False, lists) are parsed exactly as before, so setups
# with a QIDI Box are not affected.
#
# Run ON THE PRINTER (ssh mks@<printer>, default password: makerbase):
#   bash fix_save_variable_unquoted.sh           # apply
#   bash fix_save_variable_unquoted.sh --revert  # restore original file
#
# Firmware updates may overwrite the file - re-run the script afterwards.
set -euo pipefail

F=/home/qidi/klipper/klippy/extras/save_variables.py
BAK="$F.orig"
PYC_DIR=/home/qidi/klipper/klippy/extras/__pycache__

[ -f "$F" ] || { echo "ERROR: $F not found - unsupported firmware layout."; exit 1; }

# Refuse to restart Klipper in the middle of a print
STATE=$(curl -s -m 5 "http://localhost:7125/printer/objects/query?print_stats" \
        | grep -o '"state": *"[a-z]*"' | head -1 | sed 's/.*"\([a-z]*\)"$/\1/' || true)
if [ "$STATE" = "printing" ] || [ "$STATE" = "paused" ]; then
    echo "ERROR: printer is $STATE. Run this script when idle."; exit 1
fi

restart_klipper() {
    sudo rm -f "$PYC_DIR"/save_variables.*.pyc
    # FIRMWARE_RESTART does not reload Python modules - restart the service
    sudo systemctl restart klipper
    echo "Klipper restarted."
}

if [ "${1:-}" = "--revert" ]; then
    [ -f "$BAK" ] || { echo "ERROR: backup $BAK not found."; exit 1; }
    sudo cp "$BAK" "$F"
    echo "Original save_variables.py restored."
    restart_klipper
    exit 0
fi

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<'PY'
import sys
f = sys.argv[1]
s = open(f, newline='').read()
nl = '\r\n' if '\r\n' in s else '\n'
old = nl.join([
    "        except ValueError as e:",
    "            raise gcmd.error(\"Unable to parse '%s' as a literal\" % (value,))",
])
new = nl.join([
    "        except (ValueError, SyntaxError):",
    "            # QIDI firmware sends unquoted strings (e.g. VALUE=slot16) - keep as str",
    "            pass",
])
if new in s:
    print("Already patched, nothing to do."); sys.exit(2)
if s.count(old) != 1:
    print("ERROR: expected code not found - firmware differs, file NOT changed."); sys.exit(1)
s = s.replace(old, new)
compile(s, f, 'exec')  # syntax check before writing
open(f, 'w', newline='').write(s)
print("Patched.")
PY

[ -f "$BAK" ] || { sudo cp -p "$F" "$BAK"; echo "Backup saved to $BAK"; }

set +e
sudo python3 "$TMP" "$F"
RC=$?
set -e
[ $RC -eq 2 ] && exit 0
[ $RC -ne 0 ] && exit $RC

restart_klipper
echo "Done. Test: SAVE_VARIABLE VARIABLE=fix_test VALUE=hello  -> should return ok."
