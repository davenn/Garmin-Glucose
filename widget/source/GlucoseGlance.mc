import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The row in the glance list: two lines, left-aligned like the built-in
// glances.
//
//   LEVI  3M AGO
//   142 ↗ IN RANGE
//
// It only draws what is stored; fetching is the background service's job, so
// scrolling past stays quick.
(:glance)
class GlucoseGlance extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var h = dc.getHeight();
        var muted = Graphics.COLOR_LT_GRAY;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var topY = h * 0.27;
        var bottomY = h * 0.70;
        var justify = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

        var reading = Application.Storage.getValue("reading");
        var error   = Application.Storage.getValue("error");
        var title = GlucoseUi.title();

        if (!(reading instanceof Dictionary)) {
            dc.setColor(muted, Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, topY, Graphics.FONT_GLANCE,
                title + "  " + (error != null ? GlucoseUi.errorText(error) : "WAITING"), justify);
            dc.drawText(0, bottomY, Graphics.FONT_GLANCE, "---", justify);
            return;
        }

        var d = GlucoseUi.describe(reading, true);
        var text  = d[0] as String;
        var trend = d[1] as Number;
        var color = d[2] as Number;
        var word  = d[3] as String;
        var age   = GlucoseUi.ageMinutes(reading);

        // Once the number is old, why it is not updating matters more than
        // exactly how old it is.
        var status = GlucoseUi.ageText(age);
        if (error != null && age >= GlucoseUi.STALE_GREY_MIN) {
            status = GlucoseUi.errorText(error);
        }
        dc.setColor(muted, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, topY, Graphics.FONT_GLANCE, title + "  " + status, justify);

        // Number fonts carry digits only, so stale dashes use the text font.
        var font = text.equals("---") ? Graphics.FONT_GLANCE : Graphics.FONT_GLANCE_NUMBER;
        var x = dc.getTextWidthInPixels(text, font);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, bottomY, font, text, justify);

        if (trend > 0) {
            var size = (dc.getFontHeight(font) * 0.2).toNumber();
            if (size < 4) { size = 4; }
            GlucoseUi.drawArrow(dc, x + size * 2, bottomY, size, trend, color);
            x += size * 4;
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 6, bottomY, Graphics.FONT_GLANCE, word, justify);
    }
}
