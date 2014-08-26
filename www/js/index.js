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
        if (app.running) {
            app.running = false;
            document.getElementById('geoSwitch').innerText = 'Start tracking';
        } else {
            app.running = true;
            document.getElementById('geoSwitch').innerText = 'Stop tracking';
        }
    },

    // Update DOM on a Received Event
    receivedEvent: function(id) {
        console.log('Received Event: ' + id);
    }
};
