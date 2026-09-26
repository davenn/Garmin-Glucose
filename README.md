# Garmin-Glucose

A Connect IQ watch face for the Forerunner 255 / 255S / 955 that shows the
current CGM reading, its trend and a 3-hour sparkline beside the time.

```
        SAT 26
        10:42
      112  ➚
  IN RANGE  3M AGO
   ╱╲__╱‾‾╲__╱‾‾
```

Readings come from davenn.com's `bg_embed` endpoint, the plain-text variant of
the glucose API built for small devices. The watch only holds the
**read-only** `BG_READ_TOKEN`: never the admin secret, never Dexcom
credentials. It never calls Dexcom, so it adds no load to the Share API.

## How it works

| File | Role |
|---|---|
| `source/GlucoseApp.mc` | Registers a 5-minute background event; stores what it returns |
| `source/GlucoseService.mc` | Background process: GET `api.php?action=bg_embed&spark=36`, parse, hand back |
| `source/GlucoseView.mc` | Draws the face every minute from stored data |

Watch faces can't make web requests themselves. Connect IQ wakes a background
service at most every 5 minutes, which is also the CGM's sample rate. The
request goes through the Garmin Connect app on the phone, so the phone must be
in Bluetooth range.

The face ages the reading itself between fetches. It stores the reading's
absolute time, not `minutes_ago`:

- **< 15 min**: colored by range, with a word alongside: `LOW` red, `IN RANGE` green, `HIGH` yellow
- **15–60 min**: greyed and labelled `OLD`, followed by why fetches are failing (`NO PHONE`, `BAD TOKEN`, …)
- **≥ 60 min**: replaced by `---`. An old number shown as current is worse than none

The low and high thresholds are settings (default 70 / 180 mg/dL).

## Building

Needs the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) with
the `fr255` / `fr955` device profiles installed through the SDK Manager.

```sh
# once: a developer signing key
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt

# build for one device
monkeyc -d fr255 -f monkey.jungle -o bin/GlucoseFace.prg -y developer_key.der

# run in the simulator
connectiq &
monkeydo bin/GlucoseFace.prg fr255
```

In the simulator, set the token under **File → Edit Application Properties**.

## Getting it on the watch

**Settings only work for store-installed apps.** A sideloaded `.prg` can't be
configured from the Garmin Connect app, so there are two routes:

1. **Private beta (recommended).** Export with `monkeyc -e … -o bin/GlucoseFace.iq`
   and upload it to the Connect IQ developer dashboard as a *beta* app. Only
   your account sees it. Install it from the Connect IQ store app, then enter
   the token under the face's settings.
2. **Sideload.** Put the token directly into the `token` default in
   `resources/properties.xml` **locally, without committing it**, build, and copy
   the `.prg` to `GARMIN/APPS/` on the watch over USB.
