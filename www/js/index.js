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
        document.getElementById('sendEmail').addEventListener('click', this.onSendEmailClicked);
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

    onSendEmailClicked: function() {
        window.plugin.email.open({
            subject: "Cordova geo data",
            body: document.getElementById('geoLog').innerHTML,
            isHtml: true
        });
    },

    onGeoSwitchClicked: function() {
        if (!app.running) {
            if (document.getElementById('methodJS').checked) {
                app.startTrackingJS();
            } else {
                app.startTrackingNative();
            }

            app.running = true;
            document.getElementById('geoSwitch').innerText = 'Stop tracking';
        } else {
            if (document.getElementById('methodJS').checked) {
                app.stopTrackingJS();
            } else {
                app.stopTrackingNative();
            }

            app.running = false;
            document.getElementById('geoSwitch').innerText = 'Start tracking';
        }
    },

    startTrackingJS: function() {
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

        app.log('Started tracking in JS mode (' + JSON.stringify(options) + ')');
    },

    stopTrackingJS: function() {
        if (app.watchId) {
            navigator.geolocation.clearWatch(app.watchId);
            app.watchId = null;
            app.log('Stopped tracking in JS mode');
        }
    },

    startTrackingNative: function() {
        var options = {
            desiredAccuracy: 0,
            distanceFilter: 0,
            activityType: "AutomotiveNavigation"
        };

        window.plugins.backgroundGeoLocation.configure(app.onNativeDataReceived, app.onNativeDataError, options);
        window.plugins.backgroundGeoLocation.start();

        app.log('Started tracking in native mode (' + app.printJSON(options) + ')');
    },

    stopTrackingNative: function() {
        window.plugins.backgroundGeoLocation.stop();
        app.log('Stopped tracking in native mode');
    },

    onNativeDataReceived: function(data) {
        app.log('Lat: ' + data.latitude + ' Lng: ' + data.longitude +
                ' Acc: ' + data.accuracy + ' Spd: ' + data.speed);

        window.plugins.backgroundGeoLocation.finish();
    },

    onNativeDataError: function(error) {
        // currently not called
        app.log('Error: ' + error);
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

    printJSON: function(data) {
        return JSON.stringify(data).replace(new RegExp(',"', 'g'), ', "');
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
