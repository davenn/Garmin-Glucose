import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// A glance in the watch's glance list, opening to a full-screen widget.
//
// A background fetch every 5 minutes (the shortest interval Connect IQ allows,
// and the CGM's own sample rate) keeps the stored reading current all day, so
// the glance is already up to date when scrolled to. Opening the widget also
// fetches straight away (see GlucoseView).
//
// The whole class is (:background :glance) because both the background process
// and the glance load the app class. GlucoseView is neither, so it stays out
// of their much smaller memory budgets.
(:background :glance)
class GlucoseWidgetApp extends Application.AppBase {

    const FIVE_MINUTES = 5 * 60;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        scheduleFetches();
        var view = new GlucoseView();
        return [view, new GlucoseDelegate(view)];
    }

    function getGlanceView() {
        scheduleFetches();
        return [new GlucoseGlance()];
    }

    function getServiceDelegate() {
        return [new GlucoseService()];
    }

    // Runs in the glance or widget with whatever GlucoseService passed to
    // Background.exit(). On music watches the glance stays alive in the list,
    // so this redraws it as each reading lands.
    function onBackgroundData(data) {
        GlucoseApi.store(data);
        WatchUi.requestUpdate();
    }

    function onSettingsChanged() {
        Application.Storage.deleteValue("error");
        WatchUi.requestUpdate();
    }

    // The temporal event survives the app closing, so this only has to happen
    // once; checking first avoids pushing the next fetch back every time the
    // glance comes into view.
    function scheduleFetches() as Void {
        if (Background.getTemporalEventRegisteredTime() == null) {
            Background.registerForTemporalEvent(new Time.Duration(FIVE_MINUTES));
        }
    }
}
