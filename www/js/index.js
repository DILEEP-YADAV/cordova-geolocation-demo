var app = {
    running: false,

    initialize: function() {
        this.bindEvents();
    },

    // Bind Event Listeners
    //
    // Bind any events that are required on startup. Common events are:
    // 'load', 'deviceready', 'offline', and 'online'.
    bindEvents: function() {
        document.addEventListener('deviceready', this.onDeviceReady, false);
        document.getElementById('geoSwitch').addEventListener('click', this.onGeoSwitchClicked);
    },

    // deviceready Event Handler
    //
    // The scope of 'this' is the event. In order to call the 'receivedEvent'
    // function, we must explicity call 'app.receivedEvent(...);'
    onDeviceReady: function() {
        console.log('onDeviceReady');
        document.querySelector('.loading').style.display = 'none';
        document.getElementById('main').style.display = 'block';
    },

    onGeoSwitchClicked: function() {
        if (!app.running) {
            app.running = true;
            app.log('Started tracking');
            document.getElementById('geoSwitch').innerText = 'Stop tracking';
        } else {
            app.running = false;
            app.log('Stopped tracking');
            document.getElementById('geoSwitch').innerText = 'Start tracking';
        }
    },

    // Update DOM on a Received Event
    receivedEvent: function(id) {
        console.log('Received Event: ' + id);
    },

    pad: function(val, n) {
        var s = val + "";

        while (s.length < n) {
            s = "0" + s;
        }

        return s;
    },

    log: function(text) {
        var date = new Date();
        var timestamp = app.pad(date.getHours(), 2) + ":" + app.pad(date.getMinutes(), 2) + ":" +
            app.pad(date.getSeconds(), 2) + "." + app.pad(date.getMilliseconds(), 3);
        var div = document.getElementById('geoLog');
        div.innerHTML = "[" + timestamp + "] " + text + "<br>" + div.innerHTML;
    }
};
