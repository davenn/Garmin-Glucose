import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Fetches from bg_embed rather than bg_latest/bg_history: it is plain text
// built for small devices, so there is no JSON to hold in the background
// process's limited memory, and one request returns both the current reading
// and the sparkline.
//
//   line 1   mgdl,trend,minutes_ago,in_range     e.g. 84,4,2,1
//   line 2   the last SPARK_POINTS mg/dL values, oldest first
(:background)
class GlucoseService extends System.ServiceDelegate {

    // Readings in the sparkline: 36 × 5 min = the last 3 hours.
    const SPARK_POINTS = 36;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var token = Application.Properties.getValue("token");
        if (!(token instanceof String) || token.length() == 0) {
            Background.exit({ "error" => "token" });
            return;
        }
        var url = Application.Properties.getValue("baseUrl");
        if (!(url instanceof String) || url.length() == 0) {
            url = "https://davenn.com/api.php";
        }

        Communications.makeWebRequest(
            url,
            { "action" => "bg_embed", "token" => token, "spark" => SPARK_POINTS },
            {
                :method       => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
            },
            method(:onResponse)
        );
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (code != 200 || !(data instanceof String)) {
            Background.exit({ "error" => code });
            return;
        }

        var nl = data.find("\n");
        var head = splitNumbers(nl == null ? data : data.substring(0, nl));
        if (head.size() < 3) {
            Background.exit({ "error" => "parse" });
            return;
        }

        // mgdl 0 is the server saying nothing is stored yet, not a real low.
        if (head[0] == 0) {
            Background.exit({ "error" => "empty" });
            return;
        }

        var spark = [];
        if (nl != null) {
            spark = splitNumbers(data.substring(nl + 1, data.length()));
        }

        // Store the reading's absolute time, not minutes_ago: the face redraws
        // every minute between fetches and has to age the number on its own.
        Background.exit({
            "mgdl"  => head[0],
            "trend" => head[1],
            "at"    => Time.now().value() - head[2] * 60,
            "spark" => spark
        });
    }

    // "84,4,2,1" → [84, 4, 2, 1]. Stops at the first newline or anything else
    // that is not a digit or a comma.
    function splitNumbers(s as String) as Array<Number> {
        var out = [];
        var chars = s.toCharArray();
        var n = 0;
        var inNumber = false;
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i].toNumber();
            if (c >= 48 && c <= 57) {          // '0'..'9'
                n = n * 10 + (c - 48);
                inNumber = true;
            } else if (c == 44) {              // ','
                if (inNumber) { out.add(n); }
                n = 0;
                inNumber = false;
            } else if (c == 45) {              // '-'
                // Only appears as minutes_ago = -1 alongside mgdl 0, which
                // onResponse rejects before the value is ever used.
                continue;
            } else {
                break;
            }
        }
        if (inNumber) { out.add(n); }
        return out;
    }
}
