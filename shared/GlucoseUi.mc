import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;

// Drawing shared by the activity data field and the widget. draw() adapts to
// the space it is given:
//
//   small  (data field top/bottom row, quarter)   value + arrow
//   medium (half screen)                          value + arrow, status line
//   large  (full screen, the widget)              label, value + arrow, status, sparkline
(:glance)
module GlucoseUi {

    // A reading older than this is greyed out, and older than STALE_HIDE_MIN
    // it is replaced by dashes. An old number presented as current is worse
    // than no number — and on the wrist it only gets a glance.
    const STALE_GREY_MIN = 15;
    const STALE_HIDE_MIN = 60;

    // Dexcom's trend ordering, as bg_embed sends it. Angle in degrees
    // (0 = right, 90 = up); 1 and 7 are the double arrows.
    const TREND_ANGLES = [0, 90, 90, 45, 0, -45, -90, -90];

    // Largest first. Number fonts carry digits only, so dashes and words use
    // the text fonts after them.
    const NUMBER_FONTS = [
        Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT,
        Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD,
        Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY
    ];
    const TEXT_FONTS = [
        Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY
    ];

    // Clears to bg and draws the stored reading into the whole dc.
    function draw(dc as Dc, bg as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        var dark = bg == Graphics.COLOR_BLACK;
        var fg = dark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var muted = dark ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY;
        dc.setColor(fg, bg);
        dc.clear();

        var large  = h >= 150;
        var medium = !large && h >= 80;

        var reading = Application.Storage.getValue("reading");
        var error   = Application.Storage.getValue("error");

        // Vertical bands, as fractions of the space.
        var valueY = large ? h * 0.40 : (medium ? h * 0.40 : h * 0.5);
        var valueH = large ? h * 0.36 : (medium ? h * 0.58 : h * 0.9);
        var maxW   = w * (large ? 0.70 : 0.90);
        var statusY = h * (large ? 0.66 : 0.82);

        if (large) {
            drawCentered(dc, cx, h * 0.14, Graphics.FONT_XTINY, title(), muted);
        }

        if (!(reading instanceof Dictionary)) {
            drawValue(dc, cx, valueY, maxW, valueH, "---", 0, muted);
            if (large || medium) {
                drawCentered(dc, cx, statusY, Graphics.FONT_XTINY,
                    error != null ? errorText(error) : "WAITING", muted);
            }
            return;
        }

        var d = describe(reading, dark);
        var age = ageMinutes(reading);
        drawValue(dc, cx, valueY, maxW, valueH, d[0], d[1], d[2]);

        if (large || medium) {
            drawCentered(dc, cx, statusY, Graphics.FONT_XTINY, statusText(d[3], age, error), muted);
        }

        var spark = reading.get("spark") as Array<Number>?;
        if (large && spark != null && spark.size() > 1 && age < STALE_HIDE_MIN) {
            drawSparkline(dc, (w * 0.22).toNumber(), (h * 0.74).toNumber(),
                (w * 0.56).toNumber(), (h * 0.14).toNumber(), spark, fg, dark);
        }
    }

    // How to show a reading: [text, trend (0 = no arrow), color, word].
    //
    // Status colours are paired with a word wherever there is room for one, so
    // low/high survive colour-blind vision and a sunlit screen. The MIP
    // palette's yellow vanishes on white, so high is orange there.
    function describe(reading as Dictionary, dark as Boolean) as Array {
        var mgdl  = reading.get("mgdl") as Number;
        var trend = reading.get("trend") as Number;
        var age   = ageMinutes(reading);
        var muted = dark ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY;

        var color;
        var word;
        if (mgdl < numberSetting("lowMgdl", 70)) {
            color = Graphics.COLOR_RED;
            word = "LOW";
        } else if (mgdl > numberSetting("highMgdl", 180)) {
            color = dark ? Graphics.COLOR_YELLOW : Graphics.COLOR_ORANGE;
            word = "HIGH";
        } else {
            color = dark ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GREEN;
            word = "IN RANGE";
        }

        var text = mgdl.toString();
        if (trend < 1 || trend > 7) { trend = 0; }
        if (age >= STALE_HIDE_MIN) {
            return ["---", 0, muted, "STALE"];
        } else if (age >= STALE_GREY_MIN) {
            color = muted;
            word = "OLD";
        }
        return [text, trend, color, word];
    }

    // "IN RANGE  3M AGO", or once the reading is old, why it is not updating.
    // A failed fetch only matters once it shows: while the reading is fresh
    // the next one will usually succeed.
    function statusText(word as String, age as Number, error) as String {
        if (error != null && age >= STALE_GREY_MIN) {
            return ageText(age) + "  " + errorText(error);
        }
        return word + "  " + ageText(age);
    }

    // The name set in settings (e.g. whose readings these are), or GLUCOSE.
    function title() as String {
        var name = Application.Properties.getValue("name");
        if (name instanceof String && name.length() > 0) {
            return name.toUpper();
        }
        return "GLUCOSE";
    }

    // Draws the value and trend arrow as one unit centred on (cx, cy), in the
    // largest font that fits the box.
    function drawValue(dc as Dc, cx as Numeric, cy as Numeric, maxW as Numeric, maxH as Numeric,
                       text as String, trend as Number, color as Number) as Void {
        var fonts = text.equals("---") ? TEXT_FONTS : NUMBER_FONTS;
        var font = fonts[fonts.size() - 1];
        var textW = 0;
        var arrowSize = 0;
        for (var i = 0; i < fonts.size(); i++) {
            var f = fonts[i];
            // Number fonts carry a lot of padding; the digits themselves are
            // roughly three quarters of the reported height.
            var fh = dc.getFontHeight(f);
            var size = trend > 0 ? (fh * 0.16).toNumber() : 0;
            var tw = dc.getTextWidthInPixels(text, f);
            if (fh * 0.75 <= maxH && tw + size * 3 <= maxW) {
                font = f;
                textW = tw;
                arrowSize = size;
                break;
            }
        }
        if (textW == 0) {
            textW = dc.getTextWidthInPixels(text, font);
            arrowSize = trend > 0 ? (dc.getFontHeight(font) * 0.16).toNumber() : 0;
        }
        if (arrowSize < 3 && trend > 0) { arrowSize = 3; }

        var gap = trend > 0 ? arrowSize * 3 : 0;
        var left = cx - (textW + gap) / 2;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, cy, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (trend > 0) {
            drawArrow(dc, left + textW + gap / 2, cy, arrowSize, trend, color);
        }
    }

    // Shaft plus one or two heads, rotated to the trend angle, centred on (x, y).
    function drawArrow(dc as Dc, x as Numeric, y as Numeric, size as Number, trend as Number, color as Number) as Void {
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

    // The last few hours of readings, with the target range as two lines.
    // bg_embed sends values without timestamps, so a gap in the data is drawn
    // closed up rather than as a hole.
    function drawSparkline(dc as Dc, x as Number, y as Number, w as Number, h as Number,
                           vals as Array<Number>, fg as Number, dark as Boolean) as Void {
        var low  = numberSetting("lowMgdl", 70);
        var high = numberSetting("highMgdl", 180);
        var lo = low - 20;
        var hi = high + 20;
        for (var i = 0; i < vals.size(); i++) {
            if (vals[i] < lo) { lo = vals[i]; }
            if (vals[i] > hi) { hi = vals[i]; }
        }
        var span = (hi - lo).toFloat();

        var yLow  = y + h - ((low  - lo) / span * h);
        var yHigh = y + h - ((high - lo) / span * h);
        dc.setColor(dark ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, yLow, x + w, yLow);
        dc.drawLine(x, yHigh, x + w, yHigh);

        var highColor = dark ? Graphics.COLOR_YELLOW : Graphics.COLOR_ORANGE;
        var step = w.toFloat() / (vals.size() - 1);
        dc.setPenWidth(2);
        for (var i = 1; i < vals.size(); i++) {
            var v = vals[i];
            dc.setColor(v < low ? Graphics.COLOR_RED : (v > high ? highColor : fg), Graphics.COLOR_TRANSPARENT);
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

    // Minutes since the reading was taken, from its stored absolute time.
    function ageMinutes(reading as Dictionary) as Number {
        var age = (Time.now().value() - (reading.get("at") as Number)) / 60;
        return age < 0 ? 0 : age;
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
