import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Layout, top to bottom: date, time, glucose + trend arrow, status line,
// 3-hour sparkline. Positions are fractions of the screen so the same code
// serves the 260px FR255/955 and the 218px FR255S.
class GlucoseView extends WatchUi.WatchFace {

    // A reading older than this is greyed out, and older than STALE_HIDE_MIN
    // it is replaced by dashes. An old number presented as current is worse
    // than no number.
    const STALE_GREY_MIN = 15;
    const STALE_HIDE_MIN = 60;

    // Dexcom's trend ordering, as bg_embed sends it. Angle in degrees
    // (0 = right, 90 = up); 1 and 7 are the double arrows.
    const TREND_ANGLES = [0, 90, 90, 45, 0, -45, -90, -90];

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        drawClock(dc, cx, h);

        var low  = numberSetting("lowMgdl", 70);
        var high = numberSetting("highMgdl", 180);

        var reading = Application.Storage.getValue("reading");
        var error   = Application.Storage.getValue("error");

        if (!(reading instanceof Dictionary)) {
            drawCentered(dc, cx, h * 0.52, Graphics.FONT_LARGE, "---", Graphics.COLOR_DK_GRAY);
            drawCentered(dc, cx, h * 0.68, Graphics.FONT_XTINY,
                error != null ? errorText(error) : "WAITING", Graphics.COLOR_LT_GRAY);
            return;
        }

        var mgdl  = reading.get("mgdl") as Number;
        var trend = reading.get("trend") as Number;
        var at    = reading.get("at") as Number;
        var spark = reading.get("spark") as Array<Number>?;

        var age = (Time.now().value() - at) / 60;
        if (age < 0) { age = 0; }

        // Status colours are always paired with a word, so low/high survive
        // colour-blind vision and the MIP screen's washed-out palette in sun.
        var color;
        var word;
        if (mgdl < low) {
            color = Graphics.COLOR_RED;
            word = "LOW";
        } else if (mgdl > high) {
            color = Graphics.COLOR_YELLOW;
            word = "HIGH";
        } else {
            color = Graphics.COLOR_GREEN;
            word = "IN RANGE";
        }

        // Number fonts carry digits only, so the dashes need a text font.
        var valueText = mgdl.toString();
        var font = Graphics.FONT_NUMBER_MEDIUM;
        if (age >= STALE_HIDE_MIN) {
            font = Graphics.FONT_LARGE;
            valueText = "---";
            color = Graphics.COLOR_DK_GRAY;
            word = "STALE";
        } else if (age >= STALE_GREY_MIN) {
            color = Graphics.COLOR_LT_GRAY;
            word = "OLD";
        }

        // Value and arrow are centred together as one unit.
        var valueW = dc.getTextWidthInPixels(valueText, font);
        var arrowSize = (h * 0.055).toNumber();
        var showArrow = age < STALE_HIDE_MIN && trend >= 1 && trend <= 7;
        var gap = showArrow ? arrowSize * 3 : 0;
        var left = cx - (valueW + gap) / 2;
        var vy = h * 0.52;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, vy, font, valueText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (showArrow) {
            drawArrow(dc, left + valueW + gap / 2, vy, arrowSize, trend, color);
        }

        // A failed fetch only matters once it shows: while the reading is
        // fresh the next one will usually succeed. The word is dropped to make
        // room — by then it is OLD or STALE and the colour is grey anyway.
        var status = word + "  " + ageText(age);
        if (error != null && age >= STALE_GREY_MIN) {
            status = ageText(age) + "  " + errorText(error);
        }
        drawCentered(dc, cx, h * 0.665, Graphics.FONT_XTINY, status, Graphics.COLOR_LT_GRAY);

        if (spark != null && spark.size() > 1 && age < STALE_HIDE_MIN) {
            drawSparkline(dc, (w * 0.22).toNumber(), (h * 0.73).toNumber(),
                (w * 0.56).toNumber(), (h * 0.14).toNumber(), spark, low, high);
        }
    }

    function drawClock(dc as Dc, cx as Number, h as Number) as Void {
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var time = hour.format("%d") + ":" + clock.min.format("%02d");

        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var date = (info.day_of_week as String).toUpper() + " " + info.day.format("%d");

        drawCentered(dc, cx, h * 0.14, Graphics.FONT_XTINY, date, Graphics.COLOR_LT_GRAY);
        drawCentered(dc, cx, h * 0.28, Graphics.FONT_NUMBER_MILD, time, Graphics.COLOR_WHITE);
    }

    // Shaft plus one or two heads, rotated to the trend angle, centred on (x, y).
    function drawArrow(dc as Dc, x as Number, y as Numeric, size as Number, trend as Number, color as Number) as Void {
        var a = Math.toRadians(TREND_ANGLES[trend]);
        var dx = Math.cos(a);
        var dy = -Math.sin(a);
        var px = -dy;
        var py = dx;

        var tipX = x + dx * size;
        var tipY = y + dy * size;
        var tailX = x - dx * size;
        var tailY = y - dy * size;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(size / 3 > 2 ? size / 3 : 2);
        dc.drawLine(tailX, tailY, tipX, tipY);
        dc.setPenWidth(1);

        var head = size * 0.9;
        var heads = (trend == 1 || trend == 7) ? 2 : 1;
        for (var i = 0; i < heads; i++) {
            var hx = tipX - dx * head * 0.8 * i;
            var hy = tipY - dy * head * 0.8 * i;
            dc.fillPolygon([
                [hx, hy],
                [hx - dx * head + px * head * 0.6, hy - dy * head + py * head * 0.6],
                [hx - dx * head - px * head * 0.6, hy - dy * head - py * head * 0.6]
            ]);
        }
    }

    // The last few hours of readings, with the target range as a band.
    // bg_embed sends values without timestamps, so a gap in the data is drawn
    // closed up rather than as a hole.
    function drawSparkline(dc as Dc, x as Number, y as Number, w as Number, h as Number,
                           vals as Array<Number>, low as Number, high as Number) as Void {
        var lo = low - 20;
        var hi = high + 20;
        for (var i = 0; i < vals.size(); i++) {
            if (vals[i] < lo) { lo = vals[i]; }
            if (vals[i] > hi) { hi = vals[i]; }
        }
        var span = (hi - lo).toFloat();

        var yLow  = y + h - ((low  - lo) / span * h);
        var yHigh = y + h - ((high - lo) / span * h);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, yLow, x + w, yLow);
        dc.drawLine(x, yHigh, x + w, yHigh);

        var step = w.toFloat() / (vals.size() - 1);
        dc.setPenWidth(2);
        for (var i = 1; i < vals.size(); i++) {
            var v = vals[i];
            dc.setColor(v < low ? Graphics.COLOR_RED : (v > high ? Graphics.COLOR_YELLOW : Graphics.COLOR_WHITE),
                Graphics.COLOR_TRANSPARENT);
            dc.drawLine(
                x + step * (i - 1), y + h - ((vals[i - 1] - lo) / span * h),
                x + step * i,       y + h - ((v - lo) / span * h)
            );
        }
        dc.setPenWidth(1);
    }

    function drawCentered(dc as Dc, x as Numeric, y as Numeric, font as Graphics.FontType, text as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function ageText(min as Number) as String {
        if (min < 1) { return "NOW"; }
        if (min < 60) { return min.toString() + "M AGO"; }
        return (min / 60).toString() + "H AGO";
    }

    // Why the last fetch failed. Codes are Connect IQ's: -104 is the phone
    // being out of Bluetooth range, which is by far the common one.
    function errorText(err) as String {
        if (err instanceof String) {
            if (err.equals("token")) { return "SET TOKEN"; }
            if (err.equals("empty")) { return "NO DATA"; }
            return "BAD REPLY";
        }
        if (err == -104) { return "NO PHONE"; }
        if (err == 401)  { return "BAD TOKEN"; }
        return "ERR " + err.toString();
    }

    function numberSetting(key as String, fallback as Number) as Number {
        var v = Application.Properties.getValue(key);
        return v instanceof Number ? v : fallback;
    }
}
