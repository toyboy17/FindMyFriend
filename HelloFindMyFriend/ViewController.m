//
//  ViewController.m
//  HelloFindMyFriend
//
//  Created by toyboy17 on 2016/5/23.
//  Copyright © 2016年 @ demand;. All rights reserved.
//
//framework函數庫記得要先引用
#import "ViewController.h"
#import <MapKit/MapKit.h>//地圖framework
#import <CoreLocation/CoreLocation.h>//定位framework
#import "FMDB.h"
#import "FMDatabase.h"


@interface ViewController ()<MKMapViewDelegate,CLLocationManagerDelegate>
//將Map View Delegate給ViewController
{
    CLLocationManager *locationManager;
    CLLocation * currentLocation;
    
    NSArray *result;
    NSDictionary * jsonResult;
    
    NSMutableArray * path;
    MKPolylineRenderer * renderer;
    
    NSString * latitude;
    NSString * longitude;

    NSInteger targetIndex1;
    FMDatabase * db ;
}

@property (weak, nonatomic) IBOutlet MKMapView *mainMapView;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString * documentDirectory = [paths objectAtIndex:0];
    
    NSString * dbPath = [documentDirectory stringByAppendingPathComponent:@"MyDatabase.db"];
    
    db = [FMDatabase databaseWithPath:dbPath] ;
    
    if (![db open]) {
        NSLog(@"Could not open db.");
        return ;
    }
    
    if (db == nil) {
        [db executeUpdate:@"CREATE TABLE location (longitude text,latitude text)"];

    }
    
    path = [[NSMutableArray alloc] init];
    locationManager = [CLLocationManager new];//new = alloc init
    
    //取得user同意授權，//檢查是否支援IOS7.0//是否支援requestAlwaysAuthorization
    //如果有支援則執行IOS8.0以上的方法
    if([locationManager respondsToSelector:@selector(requestAlwaysAuthorization)])
    {
        [locationManager requestAlwaysAuthorization];//ios8之後才有的方法
    }
    
    //prepare locationManager，取得我所設定(期待的)位置精確度
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    //kCLLocationAccuracyBest最佳精確度，會啟動GPS，每秒回報位置
    
    locationManager.activityType = CLActivityTypeAutomotiveNavigation;
    //行動類別：AutomotiveNavigation車用導航等級
    locationManager.delegate = self;//回報給我的viewcontroller
    [locationManager startUpdatingLocation];//開始回報位置
    
    
   
    //[db executeUpdate:@"DROP TABLE MyDatabase"];
    //[db executeUpdate:@"DELETE FROM location"];
}


#pragma mark - MapType
//地圖型態  標準|衛星|混合|軌跡
- (IBAction)mapTypeChanged:(id)sender {
    //sender.selectedSegmentIndex;使用UISegmentController類別
    //selectedSegmentIndex是UISegmentController的屬性
    
    NSInteger targetIndex = [sender selectedSegmentIndex];
    //宣告地圖欄目的SegmentIndex變數，為整數
    
    switch (targetIndex) {
        case 0:
            _mainMapView.mapType = MKMapTypeStandard;
            break;
        case 1:
            _mainMapView.mapType = MKMapTypeSatellite;
            break;
        case 2:
            _mainMapView.mapType = MKMapTypeHybrid;
            break;
        case 3:
            targetIndex1=1;
            [self drawRoute];
            break;
        default:
            break;
    }
}


#pragma mark - Tracking
//追蹤模式：無｜追蹤｜追蹤與方向
- (IBAction)trackingModeChanged:(UISegmentedControl*)sender {
    
    NSInteger targetIndex = sender.selectedSegmentIndex;
    
    switch (targetIndex) {
        case 0:
            _mainMapView.userTrackingMode = MKUserTrackingModeNone;//無追蹤
            break;
        case 1:
            _mainMapView.userTrackingMode = MKUserTrackingModeFollow;//追蹤
            break;
        case 2:
            _mainMapView.userTrackingMode = MKUserTrackingModeFollowWithHeading;//追蹤與方向
            break;
        default:
            break;
    }
    
}

#pragma mark - Upload Location or not

- (IBAction)locationSwitcher:(id)sender
{
    UISwitch * onOrOff =  (UISwitch *)sender;
    if(onOrOff.on) {//switchButton打開時，傳送使用者的姓名與經緯度

    CLLocationDegrees latitude1 = currentLocation.coordinate.latitude;
    CLLocationDegrees longitude1 = currentLocation.coordinate.longitude;
    NSString * urlString = [NSString stringWithFormat:@"http://class.softarts.cc/FindMyFriends/updateUserLocation.php?GroupName=ap102&UserName=toyboy17&Lat=%f&Lon=%f",latitude1,longitude1];
        
    NSURL * url = [NSURL URLWithString:urlString];
        
    //Prepare NSURLSession固定程式碼，複製到任何地方都適用
    //產生一個設定 預設的
    NSURLSessionConfiguration * config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession * session = [NSURLSession sessionWithConfiguration:config];
        
    NSURLSessionDataTask * task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
        if (error) {
            NSLog(@"Error: %@",error);
                
            return;
        }
            
        //Convert(轉換) NSData to NSString
        NSString * content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
        NSLog(@"Server Reply JSON: %@",content);

    }];
        [db executeUpdate:@"INSERT INTO location (longitude,latitude) VALUES (?,?)",
         [NSString stringWithFormat:@"%@",longitude],[NSString stringWithFormat:@"%@",latitude]];
        
        FMResultSet *rs = [db executeQuery:@"SELECT * FROM location"];
        
        while ([rs next]) {
            
            NSString *longitudequery = [rs stringForColumn:@"longitude"];
            NSString *langtitudequery = [rs stringForColumn:@"latitude"];
            
            NSLog(@"%@%@",longitudequery,langtitudequery);
        }
        
        [rs close];
        
        //要讓task開始工作一定要加這行
        [task resume];
        
        }
    
}

#pragma mark - findFriendsOrNot

- (IBAction)findFriendsSwitcher:(id)sender
{
    //開關開啟後的狀態
    
    UISwitch * onOrOff =  (UISwitch *)sender;
    if(onOrOff.on)
    {
    NSString *urlstring = @"http://class.softarts.cc/FindMyFriends/queryFriendLocations.php?GroupName=ap102";
    NSURL *url = [NSURL URLWithString:urlstring];
    
    //Prepare NSURLSession  固定版型 複製到任何地方都可用
    //產生一個設定 預設的
    NSURLSessionConfiguration *config =
    [NSURLSessionConfiguration defaultSessionConfiguration];
        
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:
    
    ^(NSData *_Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
    {
                                      
        if(error)
        {
            //NSLog(@"Error:%@",error);
            return;
        }
        
        jsonResult = [NSJSONSerialization JSONObjectWithData:data
        
        options:NSJSONReadingMutableContainers  error:nil];
        
        NSArray *json = [[NSArray alloc]initWithArray:[jsonResult objectForKey:@"friends"]];
        NSLog(@"朋友資訊 %@",json);
        
        for(int i=0;i<json.count;i++)
        {
            CLLocationCoordinate2D friend;
            NSDictionary * friendsDictionary= json[i];
            MKPointAnnotation * point = [MKPointAnnotation new];
            NSString *FriendName = [friendsDictionary objectForKey:@"friendName"];
            NSString *lat = [friendsDictionary objectForKey:@"lat"];
            NSString *lon = [friendsDictionary objectForKey:@"lon"];
            friend.latitude = lat.floatValue;
            friend.longitude = lon.floatValue;
            
            
            point.title = FriendName;
            point.coordinate = friend;
            if([FriendName isEqualToString:@"toyboy17"])
            {}
            else
            {
                [self.mainMapView addAnnotation:point];
            }
            
        }
        
    }];
        //要讓task開始工作一定要加這行
        [task resume];
        
    }//Switch if ON
    
}


#pragma mark - CLLocationManagerDelegate Methods
//Protocol

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    
    currentLocation = locations.lastObject;
    //最後位置//CLLocation * currentLocation??
    //拿到一個Array給你
    //所以拿到lastObject是最新的，系統有空閒的時候一有位置出現就回報
    //如果系統底層處於忙碌不回報，當他有空時候再回報，一次把多個位置回報
    
    NSLog(@"Current Location: %.6f,%.6f",currentLocation.coordinate.latitude,currentLocation.coordinate.longitude);
    
    //轉 latitudeDouble,longitude 為String
    //currentLocation.coordinate.longitude
    
    latitude = [NSString stringWithFormat:@"%f",currentLocation.coordinate.latitude];
    longitude = [NSString stringWithFormat:@"%f",currentLocation.coordinate.longitude];
    
    if (targetIndex1 == 1) {
        [self drawRoute];
    }
    
    //make the region change just once
    //dispatch_once_t 就是一個Long型別而已
    //準備好一個changeRegionOnceTaken變數，變數預設是0
    static dispatch_once_t changeRegionOnceToken;
    
    //GCD ;dispatch_once 單例模式
    dispatch_once(&changeRegionOnceToken, ^{//run過一次後&changeRegionOnceToken會變成1
        
        MKCoordinateRegion region = _mainMapView.region;//設定region的中心
        //MKCoordinateRegion：可以讀寫region(地圖移動中心及縮放比例)的類別
        region.center = currentLocation.coordinate;//指標中央的經緯度
        region.span.latitudeDelta = 0.01;//緯度縮放比例調整0.01個緯度
        region.span.longitudeDelta = 0.01;//經度縮放比例調整0.01個經度
        
        [_mainMapView setRegion:region animated:true];
    });

    double lati = currentLocation.coordinate.latitude;
    double longti = currentLocation.coordinate.longitude;
    
    latitude = [NSString stringWithFormat:@"%f",lati];
    longitude = [NSString stringWithFormat:@"%f",longti];

    NSLog(@"%@ %@",latitude,longitude);

    
}


-(void)drawRoute {
    
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude.doubleValue, longitude.doubleValue);
    //設置一個變數coordinate取值(類別是CLLocationCoordinate2D)
    
    [path addObject:[NSValue valueWithMKCoordinate:coordinate]];
    //NSValue:將valueWithMKCoordinate的值轉為NS物件，才能存進可變陣列NSMutableArray * path
    
    CLLocationCoordinate2D coordinates[path.count];//取得path陣列長度
    
    for (int i=0;i<path.count;i++)
    {
        
        coordinates[i] = [[path objectAtIndex:i] MKCoordinateValue];
        
        NSLog(@"%@",path);
        
    }
    
    MKPolyline * polyLine = [MKPolyline polylineWithCoordinates:coordinates count:path.count];
    
    renderer = [[MKPolylineRenderer alloc] initWithPolyline:polyLine];
    
    renderer.strokeColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
    renderer.lineWidth   = 5;
    
    [_mainMapView addOverlay:polyLine];
    
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    
    return renderer;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
