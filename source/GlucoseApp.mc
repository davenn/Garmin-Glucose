import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Watch faces cannot make web requests themselves, so readings arrive through
// a background service that the OS wakes every 5 minutes — the shortest
// interval Connect IQ allows, and conveniently the CGM's own sample rate.
//
// The whole class is (:background) because the background process loads the
// app class to reach getServiceDelegate(). GlucoseView is not, so it stays out
// of the background's much smaller memory budget.
(:background)
class GlucoseApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        scheduleFetch();
        return [new GlucoseView()];
    }

    function getServiceDelegate() {
        return [new GlucoseService()];
    }

    // Runs in the foreground with whatever GlucoseService passed to
    // Background.exit(). A failed fetch keeps the last good reading: the face
    // ages it on screen rather than blanking it, and shows why it is not
    // updating.
    function onBackgroundData(data) {
        if (data instanceof Dictionary) {
            var err = data.get("error");
            if (err != null) {
                Application.Storage.setValue("error", err);
            } else {
                Application.Storage.setValue("reading", data);
                Application.Storage.deleteValue("error");
            }
        }
        WatchUi.requestUpdate();
    }

    function onSettingsChanged() {
        Application.Storage.deleteValue("error");
        scheduleFetch();
        WatchUi.requestUpdate();
    }

    function scheduleFetch() as Void {
        Background.registerForTemporalEvent(new Time.Duration(5 * 60));
    }
}
