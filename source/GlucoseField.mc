import Toybox.Activity;
import Toybox.Application;
import Toybox.Background;
import Toybox.FitContributor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// An activity data field. It draws whatever the background service last
// stored, sized to the slot it is placed in (see GlucoseUi).
//
// The value is also written to the activity's FIT file once a second, so a
// glucose line sits next to heart rate and pace afterwards.
class GlucoseField extends WatchUi.DataField {

    // FIT's "no value" for uint16. Written while the reading is stale, so the
    // activity chart shows a gap instead of carrying an old number forward.
    const FIT_INVALID = 0xFFFF;

    private var mFitField as FitContributor.Field?;

    function initialize() {
        DataField.initialize();
        mFitField = createField("glucose", 0, FitContributor.DATA_TYPE_UINT16,
            { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "mg/dL" });
    }

    // Called once a second while the activity screen is up.
    function compute(info as Activity.Info) as Void {
        // A one-shot fetch (see GlucoseApp.scheduleFetch) that never reported
        // back would leave nothing scheduled; this puts the timer back.
        if (Background.getTemporalEventRegisteredTime() == null) {
            (Application.getApp() as GlucoseApp).scheduleFetch();
        }

        var field = mFitField;
        if (field != null) {
            var reading = Application.Storage.getValue("reading");
            var value = FIT_INVALID;
            if (reading instanceof Dictionary && GlucoseUi.ageMinutes(reading) < GlucoseUi.STALE_GREY_MIN) {
                value = reading.get("mgdl") as Number;
            }
            field.setData(value);
        }
    }

    // Follows the activity screen's black or white background.
    function onUpdate(dc as Dc) as Void {
        GlucoseUi.draw(dc, getBackgroundColor());
    }
}
