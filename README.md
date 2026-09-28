# Garmin-Glucose

Two Connect IQ apps for the Forerunner 255 / 255 Music / 255S / 955 that show
the current CGM reading and its trend:

- **Glance + widget** (`widget/`): a row in the watch's glance list, any time
  of day. Select it for the full screen with a 3-hour sparkline.
- **Activity data field** (root): the reading during a run, recorded into the
  activity so it can be charted next to heart rate and pace afterwards.

Readings come from davenn.com's `bg_embed` endpoint, the plain-text variant of
the glucose API built for small devices. The watch only holds the
**read-only** `BG_READ_TOKEN`, sent in the `X-BG-Token` header: never the
admin secret, never Dexcom credentials. It never calls Dexcom.

## The glance and widget

In the glance list (press UP or DOWN from the watch face):

```
LEVI  3M AGO
142 ↗ IN RANGE
```

The first line shows the **name** setting (`GLUCOSE` if it is empty) and how old
the reading is. Once the reading is old, it shows why fetches are failing
instead. Press START on the glance to open the full screen: the same layout as
the full-screen data field. It fetches straight away, shows `UPDATING` while it
waits, and fetches again on START.

A background fetch runs every 5 minutes all day, whether or not the widget is
open, so the glance is already current when you scroll to it. Music watches
keep glances running, so the glance also redraws as each reading comes in.

## What the data field shows

The field adapts to the slot it is placed in:

| Slot | Shows |
|---|---|
| Small (top/bottom row, quarter) | value + trend arrow |
| Half screen | value + arrow, status line (`IN RANGE  3M AGO`) |
| Full screen | label, value + arrow, status, 3-hour sparkline |

It follows the activity screen's black or white background. Ageing is
measured from the reading's own time:

- **< 15 min**: colored by range, with a word where there is room: `LOW` red, `IN RANGE` green, `HIGH` yellow (orange on white)
- **15–60 min**: greyed, labelled `OLD`, followed by why fetches are failing (`NO PHONE`, `BAD TOKEN`, …)
- **≥ 60 min**: replaced by `---`. An old number shown as current is worse than none

The low and high thresholds are settings (default 70 / 180 mg/dL).

**This is not an alarm.** Keep Dexcom's own alerts on the phone.

## How it works

| File | Role |
|---|---|
| `shared/GlucoseApi.mc` | GET `api.php?action=bg_embed&spark=36`, parse, store |
| `shared/GlucoseService.mc` | Background process: fetch, hand the result to the app |
| `shared/GlucoseUi.mc` | Colours, ageing, value + arrow, sparkline, adaptive layout |
| `resources/` | Settings, strings, icon (both apps) |
| `source/GlucoseApp.mc` | Data field: schedules fetches during an activity |
| `source/GlucoseField.mc` | Data field: draws; writes the value to the activity's FIT file |
| `resources-field/fit/fitcontributions.xml` | How the recorded value is labelled in Garmin Connect |
| `widget/source/GlucoseWidgetApp.mc` | Widget: schedules the all-day 5-minute fetch |
| `widget/source/GlucoseGlance.mc` | Widget: the two-line glance |
| `widget/source/GlucoseView.mc` | Widget: full screen; fetches on open and on START |

The two apps are separate Connect IQ projects (`monkey.jungle` at the root,
`widget/monkey.jungle`) built from the same `shared/` code and `resources/`.
They are installed and configured separately.

Data fields fetch through a background service that Connect IQ wakes at most
every 5 minutes, which is also the CGM's sample rate. Since a field only runs
during an activity, the first fetch fires as soon as the activity opens rather
than 5 minutes in.

The request goes through the Garmin Connect app on the phone, so **the phone has
to come on the run**. The Dexcom sensor sends to the phone too, so without it
there is nothing fresh to show anyway.

While the reading is stale, the recorded value is FIT's "no value" rather than
the old number, so the activity chart shows a gap instead of a flat line.
Garmin Connect only charts recorded values for apps installed from the store;
for a sideloaded build the data is still in the `.fit` file.

## Building

Needs the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) with
the Forerunner 255 / 955 device profiles installed through the SDK Manager, plus
the Monkey C extension for VS Code.

1. **Monkey C: Verify Installation**, then **Monkey C: Generate a Developer Key**.
   Keep the key outside the repo and backed up: store updates must be signed
   with the same key.
2. Open this folder and press **Ctrl+F5**, choosing `fr255`.
3. In the simulator, set `token` under **File → Edit Persistent Storage →
   Edit Application.Properties data**.
4. Start an activity in the simulator (**Simulation → Activity Data**) and
   trigger a fetch with **Simulation → Background Events → Temporal Event**.

Command line equivalent:

```sh
monkeyc -d fr255 -f monkey.jungle -o bin/Glucose.prg -y developer_key.der
monkeydo bin/Glucose.prg fr255
```

For the widget, open `widget/` as the folder (or pass `-f widget/monkey.jungle`)
and choose `fr255m`. The simulator can show the glance or the full widget; switch
between them in its menus. Trigger a background fetch the same way, or open the
widget, which fetches on its own.

```sh
monkeyc -d fr255m -f widget/monkey.jungle -o bin/GlucoseWidget.prg -y developer_key.der
monkeydo bin/GlucoseWidget.prg fr255m
```

## Getting it on the watch

**Settings only work for store-installed apps**, so:

1. **Private beta (recommended).** **Monkey C: Export Project** gives a `.iq`;
   upload it to the Connect IQ developer dashboard as a *beta* app. Install it
   from the Connect IQ app on the phone and enter the token in its settings.
   Recorded glucose shows in Garmin Connect's activity charts.
2. **Sideload.** Put the token into the `token` default in
   `resources/properties.xml` **locally, without committing it**, run
   **Monkey C: Build for Device**, and copy the `.prg` to `GARMIN/APPS/` over USB.

Enter the token (and optionally the name, e.g. `Levi`) in each app's settings.

The widget adds itself to the glance list; reorder it from the watch face →
hold UP → Glances. Add the data field to an activity screen on the watch: open the activity (e.g. Run) →
hold UP → Run Settings → Data Screens → pick a screen → change a field →
Connect IQ → Glucose.
