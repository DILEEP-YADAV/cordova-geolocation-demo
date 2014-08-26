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

        document.addEventListener('resign', this.onAppResign);
        document.addEventListener('pause', this.onAppPause);
        document.addEventListener('active', this.onAppActive);
        document.addEventListener('resume', this.onAppResume);

        document.getElementById('geoSwitch').addEventListener('click', this.onGeoSwitchClicked);
        document.getElementById('geoLogClear').addEventListener('click', this.onGeoLogClearClicked);
    },

    // deviceready Event Handler
    //
    // The scope of 'this' is the event. In order to call the 'receivedEvent'
    // function, we must explicity call 'app.receivedEvent(...);'
    onDeviceReady: function() {
        document.getElementById('geoLog').innerHTML = localStorage['log'] ? localStorage['log'] : '';

        document.querySelector('.loading').style.display = 'none';
        document.getElementById('main').style.display = 'block';

        app.log('--- App started ---');
    },

    onAppResign: function() {
        app.log('--- App became inactive ---');
    },

    onAppPause: function() {
        app.log('--- App went into background ---');
    },

    onAppActive: function() {
        app.log('--- App became active ---');
    },

    onAppResume: function() {
        app.log('--- App moved into foreground ---');
    },

    onGeoSwitchClicked: function() {
        if (!app.running) {
            var options = {};

            var frequency = document.getElementById('optionFrequency').value;
            if (frequency != '') {
                options['maximumAge'] = parseInt(frequency, 10);
            }

            if (document.getElementById('optionHighAccuracy').checked) {
                options['enableHighAccuracy'] = true;
            }

            app.watchId = navigator.geolocation.watchPosition(app.onGeoDataReceived,
                                                              app.onGeoError,
                                                              options);

            app.running = true;
            app.log('Started tracking (' + JSON.stringify(options) + ')');
            document.getElementById('geoSwitch').innerText = 'Stop tracking';
        } else {
            app.running = false;
            app.log('Stopped tracking');
            document.getElementById('geoSwitch').innerText = 'Start tracking';

            if (app.watchId) {
                navigator.geolocation.clearWatch(app.watchId);
                app.watchId = null;
            }
        }
    },

    onGeoDataReceived: function(position) {
        app.log('Lat: ' + position.coords.latitude + ' Lng: ' + position.coords.longitude +
                ' Acc: ' + position.coords.accuracy + ' Spd: ' + position.coords.speed);
    },

    onGeoError: function(error) {
        app.log('Error ' + error.code + ': ' + error.message);
    },

    onGeoLogClearClicked: function() {
        document.getElementById('geoLog').innerHTML = '';
        localStorage['log'] = '';
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

        console.log(text);

        localStorage['log'] = div.innerHTML;
    }
};
