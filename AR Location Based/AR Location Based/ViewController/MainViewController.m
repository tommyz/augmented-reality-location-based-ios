//
//  ViewController.m
//  AR Location Based
//
//  Created by Jhonathan Wyterlin on 09/05/15.
//  Copyright (c) 2015 Jhonathan Wyterlin. All rights reserved.
//

#import "MainViewController.h"
#import "FlipsideViewController.h"
@import GooglePlaces;
//@import GMSPlacePickerConfig;
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

// Service Layer
#import "PlacesLoader.h"

// Model
#import "Place.h"
#import "PlaceAnnotation.h"

NSString * const kNameKey = @"name";
NSString * const kReferenceKey = @"reference";
NSString * const kAddressKey = @"vicinity";
NSString * const kLatitudeKeypath = @"geometry.location.lat";
NSString * const kLongitudeKeypath = @"geometry.location.lng";

@interface MainViewController ()<FlipsideViewControllerDelegate,CLLocationManagerDelegate,MKMapViewDelegate>
{
    GMSPlacesClient *_placesClient;
}
@property (nonatomic,strong) MKMapView *mapView;
@property (nonatomic,strong) IBOutlet MKMapView *mapViewVertical;
@property (nonatomic,strong) IBOutlet MKMapView *mapViewHorizontal;
@property (nonatomic,strong) IBOutlet UIButton *cameraButton;
@property (nonatomic,strong) IBOutlet UIButton *cameraButtonHorizontal;
@property (nonatomic,strong) CLLocationManager *locationManager;
@property (nonatomic,strong) NSArray *locations;

@end

const double MAX_DISTANCE_ACCURACY_IN_METERS = 100.0;

@implementation MainViewController

#pragma mark - View Lifecycle

-(void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.cameraButton.layer.cornerRadius = 5.0;
    self.cameraButtonHorizontal.layer.cornerRadius = 5.0;
    
    [self setupLocationManager];
    
    self.mapView = self.mapViewVertical;
    [self.mapView setUserTrackingMode:MKUserTrackingModeFollowWithHeading];
    self.mapView.showsCompass = YES;
    _placesClient = [GMSPlacesClient sharedClient];
}

-(void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
         UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
         
         if ( UIInterfaceOrientationIsLandscape(orientation) )
             self.mapView = self.mapViewHorizontal;
         else
             self.mapView = self.mapViewVertical;

         if ( self.mapViewHorizontal.annotations.count == 0 ) {
             [self.mapViewHorizontal addAnnotations:self.mapViewVertical.annotations];
             self.mapViewHorizontal.region = self.mapViewVertical.region;
         }

     } completion:^(id<UIViewControllerTransitionCoordinatorContext> context){}];
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

}

#pragma mark - Private methods

-(void)setupLocationManager {
    
    
    if (![CLLocationManager locationServicesEnabled])
    {
        //提示用户无法进行定位操作
        NSLog(@"![CLLocationManager locationServicesEnabled]");
        //        _isUseAutoLocation = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"postGPSErrorServices" object:nil];
    }
    else
    {
        NSLog(@"nnnnnn![CLLocationManager locationServicesEnabled]");
        
        NSLog(@"[CLLocationManager authorizationStatus]=%d",[CLLocationManager authorizationStatus]);
        if ([CLLocationManager authorizationStatus] == 2)
        {
            //            _isUseAutoLocation = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"postGPSErrorDenied" object:nil];
        }
        else
        {
            
            if (_locationManager == nil)
            {
                _locationManager = [[CLLocationManager alloc] init];
                _locationManager.delegate = self;
                _locationManager.distanceFilter = kCLDistanceFilterNone;
                _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
            }
            
            // Check for iOS 8. Without this guard the code will crash with "unknown selector" on iOS 7.
            if ([_locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
                [_locationManager requestWhenInUseAuthorization];
            }
            
            _mapView.showsUserLocation = YES;
            
            [_locationManager startUpdatingLocation];
            
            if ([CLLocationManager headingAvailable]) {
                _locationManager.headingFilter = 5;
                [_locationManager startUpdatingHeading];
            }
            
        }
    }
}

#pragma mark - FlipsideViewControllerDelegate methods

-(void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Prepare for Segue

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ( [[segue identifier] isEqualToString:@"showAlternate"] ) {

        [[segue destinationViewController] setDelegate:self];
        [[segue destinationViewController] setLocations:self.locations];
        [[segue destinationViewController] setUserLocation:self.mapView.userLocation];

    }

}


#pragma mark -
#pragma mark CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    NSLog(@"didUpdateLocations locations");
    CLLocation *currentLocation = [locations lastObject];
    NSTimeInterval eventInterval = [currentLocation.timestamp timeIntervalSinceNow];
    
    if (fabs(eventInterval) < 30 && fabs(eventInterval) >= 0)
    {
        if (currentLocation.horizontalAccuracy < 0)
        {
            return;
        }
        [_locationManager stopUpdatingLocation];
        
        [self locationUpdate:currentLocation];
        
    }
    
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"locationManager didFailWithError");
    
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    if (newHeading.headingAccuracy < 0)
        return;
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    
    NSLog( @"didChangeAuthorizationStatus: %i", status );
    
    // To use in the future
    //    self.gpsDenied = ( status == kCLAuthorizationStatusDenied );
    
}

- (void)locationUpdate:(CLLocation*)tempLoaction
{
    
    NSLog(@"[_locationManager stopUpdatingLocation]");
    
    MKCoordinateSpan span = MKCoordinateSpanMake( 0.0014, 0.0014 );
//    MKCoordinateSpan span = MKCoordinateSpanMake( 0.5, 0.5 );
    MKCoordinateRegion region = MKCoordinateRegionMake( [tempLoaction coordinate], span );
    self.mapView.showsUserLocation = YES;
    [self.mapView setRegion:region animated:YES];
    
    [_placesClient currentPlaceWithCallback:^(GMSPlaceLikelihoodList *placeLikelihoodList, NSError *error){
        if (error != nil) {
            NSLog(@"Pick Place error %@", [error localizedDescription]);
            return;
        }
       
        if (placeLikelihoodList != nil) {
           
            GMSPlace *place = [[[placeLikelihoodList likelihoods] firstObject] place];
            if (place != nil) {
                NSLog(@"place=%@",place);
                NSLog(@"place.name=%@",place.name);
            }
            NSMutableArray *temp = [NSMutableArray new];
            
            for (NSInteger i = 0; i < [placeLikelihoodList likelihoods].count; i++) {
                GMSPlace *place = [[[placeLikelihoodList likelihoods] objectAtIndex:i] place];
                
                float latitude = place.coordinate.latitude;
                float longitude = place.coordinate.longitude;
                
                CLLocation *location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
                
                NSString *reference = @"tommyz";
                NSString *name = place.name;
                NSString *address = [[place.formattedAddress componentsSeparatedByString:@", "]
                                     componentsJoinedByString:@"\n"];
                
                Place *currentPlace = [[Place alloc] initWithLocation:location
                                                            reference:reference
                                                                 name:name
                                                              address:address];
                
                [temp addObject:currentPlace];
                
                PlaceAnnotation *annotation = [[PlaceAnnotation alloc] initWithPlace:currentPlace];
                [self.mapView addAnnotation:annotation];
            }
            self.locations = [temp copy];
        }
    }];
}


#pragma mark - Map View Delegate
-(MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    
    static NSString *identifier = @"PlaceAnnotation";
    if ([annotation isKindOfClass:[PlaceAnnotation class]]) {
        MKPinAnnotationView *annotationView = (MKPinAnnotationView *) [_mapView dequeueReusableAnnotationViewWithIdentifier:identifier];
        if (annotationView == nil) {
            annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
        } else {
            annotationView.annotation = annotation;
        }
        
        annotationView.enabled = YES;
        annotationView.canShowCallout = YES;
        
        return annotationView;
    }
    
    return nil;
}

- (void)mapView:(MKMapView *)mapView didChangeUserTrackingMode:(MKUserTrackingMode)mode animated:(BOOL)animated
{
    dispatch_async(dispatch_get_main_queue(),^{
        if ([CLLocationManager locationServicesEnabled]) {
            if ([CLLocationManager headingAvailable]) {
                [_mapView setUserTrackingMode:MKUserTrackingModeFollowWithHeading animated:NO];
            }else{
                [_mapView setUserTrackingMode:MKUserTrackingModeFollow animated:NO];
            }
        }else{
            [_mapView setUserTrackingMode:MKUserTrackingModeNone animated:NO];
        }
    });
}
@end
