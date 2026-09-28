import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Data fields fetch through a background service that the OS wakes at most
// every 5 minutes — the shortest interval Connect IQ allows, and conveniently
// the CGM's own sample rate.
//
// The whole class is (:background) because the background process loads the
// app class to reach getServiceDelegate(). GlucoseField is not, so it stays out
// of the background's much smaller memory budget.
(:background)
class GlucoseApp extends Application.AppBase {

    const FIVE_MINUTES = 5 * 60;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        scheduleFetch();
        return [new GlucoseField()];
    }

    function getServiceDelegate() {
        return [new GlucoseService()];
    }

    // Runs in the foreground with whatever GlucoseService passed to
    // Background.exit().
    function onBackgroundData(data) {
        GlucoseApi.store(data);
        // The first fetch of an activity is a one-shot; from here on, every
        // 5 minutes.
        Background.registerForTemporalEvent(new Time.Duration(FIVE_MINUTES));
        WatchUi.requestUpdate();
    }

    function onSettingsChanged() {
        Application.Storage.deleteValue("error");
        scheduleFetch();
        WatchUi.requestUpdate();
    }

    // A field only exists while an activity is open, so waiting a full period
    // would leave the first 5 minutes of every run blank. Fetch as soon as
    // Connect IQ allows instead: now if the last fetch was 5+ minutes ago,
    // otherwise the moment that window opens. onBackgroundData then switches
    // to the regular interval.
    function scheduleFetch() as Void {
        var last = Background.getLastTemporalEventTime();
        if (last == null || Time.now().compare(last) >= FIVE_MINUTES) {
            Background.registerForTemporalEvent(Time.now());
        } else {
            Background.registerForTemporalEvent(last.add(new Time.Duration(FIVE_MINUTES)));
        }
    }
}
