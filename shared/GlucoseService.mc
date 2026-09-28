import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

// The background process: wakes on the temporal event, fetches, and hands the
// result to the app's onBackgroundData.
(:background)
class GlucoseService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        if (!GlucoseApi.request(method(:onResponse))) {
            Background.exit({ "error" => "token" });
        }
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        Background.exit(GlucoseApi.parse(code, data));
    }
}
