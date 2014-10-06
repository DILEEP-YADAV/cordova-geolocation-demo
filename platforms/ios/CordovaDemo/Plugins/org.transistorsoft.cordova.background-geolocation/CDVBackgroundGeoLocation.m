////
//  CDVBackgroundGeoLocation
//
//  Created by Chris Scott <chris@transistorsoft.com> on 2013-06-15
//

#import "CDVBackgroundGeoLocation.h"

// Debug sounds for bg-geolocation life-cycle events.
// http://iphonedevwiki.net/index.php/AudioServices
#define locationSyncSound       1004
#define locationErrorSound      1073

#define LocationServicesDisabledError 1
#define LocationAccessDeniedError     2
#define LocationAccessRestrictedError 3


@implementation CDVBackgroundGeoLocation {
    BOOL isDebugging;
    BOOL isUpdatingLocation;

    UIBackgroundTaskIdentifier bgTask;
    NSDate *lastBgTaskAt;

    CLLocationManager *locationManager;
    NSMutableArray *locationQueue;

    NSInteger distanceFilter;
    NSInteger desiredAccuracy;
    CLActivityType activityType;
}

@synthesize syncCallbackId;

- (void)pluginInitialize
{
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;

    locationQueue = [[NSMutableArray alloc] init];

    isUpdatingLocation = NO;
    isDebugging = NO;

    bgTask = UIBackgroundTaskInvalid;
}

/**
 * configure plugin
 * @param {String} token
 * @param {String} url
 * @param {Number} stationaryRadius
 * @param {Number} distanceFilter
 * @param {Number} locationTimeout
 */
- (void) configure:(CDVInvokedUrlCommand*)command
{
    // in iOS, we call to javascript for HTTP now so token and url should be @deprecated until Android calls out to javascript.
    // Params.
    //    0       1       2           3               4                5               6            7           8                8               9
    //[params, headers, url, stationaryRadius, distanceFilter, locationTimeout, desiredAccuracy, debug, notificationTitle, notificationText, activityType]
    
    // UNUSED ANDROID VARS
    //params = [command.arguments objectAtIndex: 0];
    //headers = [command.arguments objectAtIndex: 1];
    //url = [command.arguments objectAtIndex: 2];
    //stationaryRadius    = [[command.arguments objectAtIndex: 3] intValue];
    //locationTimeout     = [[command.arguments objectAtIndex: 5] intValue];

    distanceFilter      = [[command.arguments objectAtIndex: 4] intValue];
    desiredAccuracy     = [self decodeDesiredAccuracy:[[command.arguments objectAtIndex: 6] intValue]];
    isDebugging         = [[command.arguments objectAtIndex: 7] boolValue];
    activityType        = [self decodeActivityType:[command.arguments objectAtIndex:9]];
    
    self.syncCallbackId = command.callbackId;
    
    locationManager.activityType = activityType;
    locationManager.pausesLocationUpdatesAutomatically = YES;
    locationManager.distanceFilter = distanceFilter; // meters
    locationManager.desiredAccuracy = desiredAccuracy;
    
    NSLog(@"CDVBackgroundGeoLocation configure");
    NSLog(@"  - distanceFilter: %ld", (long)distanceFilter);
    NSLog(@"  - desiredAccuracy: %ld", (long)desiredAccuracy);
    NSLog(@"  - activityType: %@", [command.arguments objectAtIndex:7]);
    NSLog(@"  - debug: %d", isDebugging);
}

- (void) addStationaryRegionListener:(CDVInvokedUrlCommand*)command
{
    // unused
}

- (void) setConfig:(CDVInvokedUrlCommand*)command
{
    NSLog(@"- CDVBackgroundGeoLocation setConfig");
    NSDictionary *config = [command.arguments objectAtIndex:0];
    
    if (config[@"desiredAccuracy"]) {
        desiredAccuracy = [self decodeDesiredAccuracy:[config[@"desiredAccuracy"] floatValue]];
        NSLog(@"    desiredAccuracy: %@", config[@"desiredAccuracy"]);
    }
    if (config[@"distanceFilter"]) {
        distanceFilter = [config[@"distanceFilter"] intValue];
        NSLog(@"    distanceFilter: %@", config[@"distanceFilter"]);
    }

    CDVPluginResult* result = nil;
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

-(NSInteger)decodeDesiredAccuracy:(NSInteger)accuracy
{
    switch (accuracy) {
        case 1000:
            accuracy = kCLLocationAccuracyKilometer;
            break;
        case 100:
            accuracy = kCLLocationAccuracyHundredMeters;
            break;
        case 10:
            accuracy = kCLLocationAccuracyNearestTenMeters;
            break;
        case 0:
            accuracy = kCLLocationAccuracyBest;
            break;
        default:
            accuracy = kCLLocationAccuracyHundredMeters;
    }

    return accuracy;
}

-(CLActivityType)decodeActivityType:(NSString*)name
{
    if ([name caseInsensitiveCompare:@"AutomotiveNavigation"]) {
        return CLActivityTypeAutomotiveNavigation;
    } else if ([name caseInsensitiveCompare:@"OtherNavigation"]) {
        return CLActivityTypeOtherNavigation;
    } else if ([name caseInsensitiveCompare:@"Fitness"]) {
        return CLActivityTypeFitness;
    } else {
        return CLActivityTypeOther;
    }
}

/**
 * Turn on background geolocation
 */
- (void) start:(CDVInvokedUrlCommand*)command
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    NSLog(@"- CDVBackgroundGeoLocation start (background? %ld)", (long) state);

    if (![CLLocationManager locationServicesEnabled]) {
        NSLog(@"CDVBackgroundGeoLocation start: error: location services disabled");
        [self callErrorCallbackWithCode:LocationServicesDisabledError];
        return;
    }

    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusAuthorized:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            [self startUpdatingLocation];
            break;

        case kCLAuthorizationStatusNotDetermined:
            NSLog(@"CDVBackgroundGeoLocation start: requesting authorization");
            [locationManager requestWhenInUseAuthorization];
            [self startUpdatingLocation];
            break;

        case kCLAuthorizationStatusDenied: {
            NSLog(@"CDVBackgroundGeoLocation start: error: location tracking authorization denied");
            [self callErrorCallbackWithCode:LocationAccessDeniedError];
            return;
        }

        case kCLAuthorizationStatusRestricted: {
            NSLog(@"CDVBackgroundGeoLocation start: error: location tracking is restricted on the device");
            [self callErrorCallbackWithCode:LocationAccessRestrictedError];
            return;
        }
    }

    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)callErrorCallbackWithCode:(NSInteger)errorCode {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    data[@"code"] = @(errorCode);

    switch (errorCode) {
        case LocationServicesDisabledError:
            data[@"message"] = @"Location services are disabled";
            break;

        case LocationAccessDeniedError:
            data[@"message"] = @"User has denied access to location data";
            break;

        case LocationAccessRestrictedError:
            data[@"message"] = @"Location data access is restricted on the device";
            break;
    }

    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:data];
    [self.commandDelegate sendPluginResult:result callbackId:self.syncCallbackId];
}


/**
 * Turn it off
 */
- (void) stop:(CDVInvokedUrlCommand*)command
{
    NSLog(@"- CDVBackgroundGeoLocation stop");

    [self stopUpdatingLocation];

    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

/**
 * Change pace to moving/stopped
 * @param {Boolean} isMoving
 */
- (void) onPaceChange:(CDVInvokedUrlCommand *)command
{
    // unused
}

/**
 * Fetches current stationaryLocation
 */
- (void) getStationaryLocation:(CDVInvokedUrlCommand *)command
{
    // unused

    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:NO];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (NSDictionary *) locationToHash:(CLLocation*)location {
    return @{
             @"timestamp": @([location.timestamp timeIntervalSince1970] * 1000),
             @"speed": @(location.speed),
             @"altitudeAccuracy": @(location.verticalAccuracy),
             @"accuracy": @(location.horizontalAccuracy),
             @"heading": @(location.course),
             @"altitude": @(location.altitude),
             @"latitude": @(location.coordinate.latitude),
             @"longitude": @(location.coordinate.longitude)
           };
}

/**
 * Called by js to signify the end of a background-geolocation event
 */
-(void) finish:(CDVInvokedUrlCommand*)command
{
    NSLog(@"- CDVBackgroundGeoLocation finish");
    [self stopBackgroundTask];
}

-(void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    NSLog(@"- CDVBackgroundGeoLocation didUpdateLocations");

    CLLocation *location = [locations lastObject];

    // test the age of the location measurement to determine if the measurement is cached
    // in most cases you will not want to rely on cached measurements
    if ([self locationAge:location] > 5.0) return;

    // test that the horizontal accuracy does not indicate an invalid measurement
    if (location.horizontalAccuracy < 0) return;

    [self queue:location type:@"current"];
}

-(void) queue:(CLLocation*)location type:(id)type
{
    NSLog(@"- CDVBackgroundGeoLocation queue %@", type);

    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithDictionary:[self locationToHash:location]];
    data[@"location_type"] = type;
    [locationQueue addObject:data];

    [self flushQueue];
}

- (void) flushQueue
{
    // Sanity-check the duration of last bgTask:  If greater than 30s, kill it.
    if (bgTask != UIBackgroundTaskInvalid) {
        if (-[lastBgTaskAt timeIntervalSinceNow] > 30.0) {
            NSLog(@"- CDVBackgroundGeoLocation#flushQueue has to kill an out-standing background-task!");
            if (isDebugging) {
                [self notify:@"Outstanding bg-task was force-killed"];
            }
            [self stopBackgroundTask];
        }
        return;
    }

    if ([locationQueue count] > 0) {
        NSMutableDictionary *data = [locationQueue lastObject];
        [locationQueue removeObject:data];

        // Create a background-task and delegate to Javascript for syncing location
        bgTask = [self createBackgroundTask];
        [self.commandDelegate runInBackground:^{
            [self sync:data];
        }];
    }
}

-(UIBackgroundTaskIdentifier) createBackgroundTask
{
    lastBgTaskAt = [NSDate date];
    return [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self stopBackgroundTask];
    }];
}

/**
 * We are running in the background if this is being executed.
 * We can't assume normal network access.
 * bgTask is defined as an instance variable of type UIBackgroundTaskIdentifier
 */
-(void) sync:(NSDictionary*)data
{
    NSLog(@"- CDVBackgroundGeoLocation#sync");
    NSLog(@"  type: %@, position: %@,%@ speed: %@",
          [data objectForKey:@"location_type"],
          [data objectForKey:@"latitude"],
          [data objectForKey:@"longitude"],
          [data objectForKey:@"speed"]);

    if (isDebugging) {
        [self notify:[NSString stringWithFormat:@"Location update:\nSPD: %0.0f | DF: %ld | ACY: %0.0f",
                      [[data objectForKey:@"speed"] doubleValue],
                      (long) locationManager.distanceFilter,
                      [[data objectForKey:@"accuracy"] doubleValue]]];
         
        AudioServicesPlaySystemSound (locationSyncSound);
    }

    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:data];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:self.syncCallbackId];
}

- (void) stopBackgroundTask
{
    UIApplication *app = [UIApplication sharedApplication];

    if (bgTask != UIBackgroundTaskInvalid)
    {
        [app endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }

    [self flushQueue];
}

- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager
{
    NSLog(@"- CDVBackgroundGeoLocation paused location updates");

    if (isDebugging) {
        [self notify:@"Stop detected"];
    }
}

- (void)locationManagerDidResumeLocationUpdates:(CLLocationManager *)manager
{
    NSLog(@"- CDVBackgroundGeoLocation resume location updates");

    if (isDebugging) {
        [self notify:@"Resume location updates"];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if (error.code != kCLErrorLocationUnknown) {
        NSLog(@"CDVBackgroundGeoLocation locationManager failed: %@", error);
    }

    if (isDebugging) {
        AudioServicesPlaySystemSound (locationErrorSound);
        [self notify:[NSString stringWithFormat:@"Location error: %@", error.localizedDescription]];
    }

    switch (error.code) {
        case kCLErrorLocationUnknown:
            NSLog(@"CDVBackgroundGeoLocation locationManager: can't determine user's location, will keep trying...");
            break;

        case kCLErrorNetwork:
        case kCLErrorRegionMonitoringDenied:
        case kCLErrorRegionMonitoringSetupDelayed:
        case kCLErrorRegionMonitoringResponseDelayed:
        case kCLErrorGeocodeFoundNoResult:
        case kCLErrorGeocodeFoundPartialResult:
        case kCLErrorGeocodeCanceled:
            break;

        case kCLErrorDenied:
            [self stopUpdatingLocation];
            break;

        default:
            [self stopUpdatingLocation];
    }
}

- (void) stopUpdatingLocation
{
    [locationManager stopUpdatingLocation];
    isUpdatingLocation = NO;
}

- (void) startUpdatingLocation
{
    [locationManager startUpdatingLocation];
    isUpdatingLocation = YES;
}

- (void) locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    NSLog(@"- CDVBackgroundGeoLocation didChangeAuthorizationStatus %u", status);

    if (isDebugging) {
        [self notify:[NSString stringWithFormat:@"Authorization status changed %u", status]];
    }

    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusAuthorized:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            NSLog(@"CDVBackgroundGeoLocation didChangeAuthorizationStatus: authorization granted");

            if (isUpdatingLocation) {
                [self startUpdatingLocation];
            }

            break;

        case kCLAuthorizationStatusDenied:
            NSLog(@"CDVBackgroundGeoLocation didChangeAuthorizationStatus: authorization denied");
            [self callErrorCallbackWithCode:LocationAccessDeniedError];

            if (isUpdatingLocation) {
                [self stopUpdatingLocation];
            }

            break;

        case kCLAuthorizationStatusRestricted:
            NSLog(@"CDVBackgroundGeoLocation didChangeAuthorizationStatus: access restricted");
            [self callErrorCallbackWithCode:LocationAccessRestrictedError];

            if (isUpdatingLocation) {
                [self stopUpdatingLocation];
            }

            break;

        default:
            break;
    }
}

- (NSTimeInterval) locationAge:(CLLocation*)location
{
    return -[location.timestamp timeIntervalSinceNow];
}

- (void) notify:(NSString*)message
{
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    localNotification.timeZone = [NSTimeZone defaultTimeZone];
    localNotification.fireDate = [NSDate date];
    localNotification.alertBody = message;

    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
}

- (void)dealloc
{
    locationManager.delegate = nil;
}

@end
