#require "Rocky.class.nut:2.0.1"

api <- Rocky();

api.get("/controller/appinfo", function(context) {
    // Send back the app's Controller-specific UUID and an
    // indicator to show whether Controller is supported
    local info = { "app": "<UUID>",
                   "watchsupported": "true" };
    context.send(200, http.jsonencode(info));
});

api.get("/controller/state", function(context) {
    // Send back "1" or "0" according to whether the device
    // is connected to the impCloud via WiFi
    context.send(200, device.isconnected() ? "1" : "0");
});
