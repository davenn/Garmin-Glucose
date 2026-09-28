import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// The full-screen widget: title, value + arrow, status, 3-hour sparkline.
//
// It fetches as soon as it opens rather than waiting for the next background
// fetch, since opening it is someone asking what the number is right now.
// START fetches again.
class GlucoseView extends WatchUi.View {

    private var mTimer as Timer.Timer?;
    private var mFetching as Boolean = false;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        refresh();
        // Keeps "3M AGO" counting up while the screen stays open.
        var timer = new Timer.Timer();
        timer.start(method(:onTick), 30000, true);
        mTimer = timer;
    }

    function onHide() as Void {
        if (mTimer != null) {
            mTimer.stop();
            mTimer = null;
        }
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    function refresh() as Void {
        if (mFetching) {
            return;
        }
        if (GlucoseApi.request(method(:onResponse))) {
            mFetching = true;
        } else {
            GlucoseApi.store({ "error" => "token" });
        }
        WatchUi.requestUpdate();
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        mFetching = false;
        GlucoseApi.store(GlucoseApi.parse(code, data));
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        GlucoseUi.draw(dc, Graphics.COLOR_BLACK);
        if (mFetching) {
            GlucoseUi.drawCentered(dc, dc.getWidth() / 2, dc.getHeight() * 0.93,
                Graphics.FONT_XTINY, "UPDATING", Graphics.COLOR_DK_GRAY);
        }
    }
}

class GlucoseDelegate extends WatchUi.BehaviorDelegate {

    private var mView as GlucoseView;

    function initialize(view as GlucoseView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onSelect() as Boolean {
        mView.refresh();
        return true;
    }
}
