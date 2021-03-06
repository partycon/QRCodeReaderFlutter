#import "QRCodeReaderPlugin.h"


static NSString *const CHANNEL_NAME = @"qrcodereader";
static FlutterMethodChannel *channel;

@interface QRCodeReaderPlugin()<AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic, strong) UIView *viewPreview;
@property (nonatomic, strong) UIView *qrcodeview;
@property (nonatomic, strong) UIButton *buttonStop;
@property (nonatomic) BOOL isReading;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
-(BOOL)startReading;
-(void)stopReading;
@property (nonatomic, retain) UIViewController *viewController;
@property (nonatomic, retain) UIViewController *qrcodeViewController;
@end

@implementation QRCodeReaderPlugin {
    FlutterResult _result;
    UIViewController *_viewController;
    
}
float height;
float width;
float landscapeheight;
float portraitheight;


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:CHANNEL_NAME
                                     binaryMessenger:[registrar messenger]];
//    UIViewController *viewController = (UIViewController *)registrar.messenger;
    UIViewController *viewController =
    [UIApplication sharedApplication].delegate.window.rootViewController;
    QRCodeReaderPlugin* instance = [[QRCodeReaderPlugin alloc] initWithViewController:viewController];
    [registrar addMethodCallDelegate:instance channel:channel];
    
}


- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"readQRCode" isEqualToString:call.method]) {
        [self showQRCodeView:call];
        _result = result;
    } else if ([@"stopReading" isEqualToString:call.method]) {
        [self stopReading];
        result(@"stopped");
    }else {
        result(FlutterMethodNotImplemented);
    }
}

- (instancetype)initWithViewController:(UIViewController *)viewController {
    self = [super init];
    if (self) {
        _viewController = viewController;
        //_viewController.view.backgroundColor = [UIColor  colorWithWhite:0.0 alpha:0.0];
        _viewController.view.backgroundColor = [UIColor  clearColor];
        _viewController.view.opaque = NO;
        [[ NSNotificationCenter defaultCenter]addObserver: self selector:@selector(rotate:)
                                                     name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}


- (void)showQRCodeView:(FlutterMethodCall*)call {
    _qrcodeViewController = [[UIViewController alloc] init];
    [_viewController presentViewController:_qrcodeViewController animated:NO completion:nil];
    [self loadViewQRCode];
    [self viewQRCodeDidLoad];
    [self startReading];
}

- (void)closeQRCodeView {
    [_qrcodeViewController dismissViewControllerAnimated:YES completion:^{
        [channel invokeMethod:@"onDestroy" arguments:nil];
    }];
}


//-(void)loadView
-(void)loadViewQRCode
{
    NSLog(@"loading QRCodeView");
    
    portraitheight = height = [UIScreen mainScreen].applicationFrame.size.height;
    landscapeheight = width = [UIScreen mainScreen].applicationFrame.size.width;
    
    if(UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation])){
        landscapeheight = height;
        portraitheight = width;
    }
    //_viewController.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.0];
    //_viewController.view.opaque = NO;
    _qrcodeview= [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height) ];
    _qrcodeview.opaque = NO;
    _qrcodeview.backgroundColor = [UIColor  blackColor];
    _qrcodeview.backgroundColor = [UIColor  colorWithWhite:0.0 alpha:0.0];
    _qrcodeViewController.view = _qrcodeview;

}

//- (void)viewDidLoad {
//[super viewDidLoad];
- (void)viewQRCodeDidLoad {
    
    // Normally the subviews are loaded from a nib, but we do it all programmatically in Flutter style.
    _viewPreview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height - 64) ];
    _viewPreview.backgroundColor = [UIColor blackColor];
    [_qrcodeViewController.view addSubview:_viewPreview];
    _buttonStop =  [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _buttonStop.frame =  CGRectMake(0, height - 64, width, 64);
    _buttonStop.backgroundColor = [UIColor blackColor];
    [_buttonStop setTitleColor: [UIColor whiteColor] forState:UIControlStateNormal];
    [_buttonStop setTitle:@"BACK"forState:UIControlStateNormal];
    [_buttonStop addTarget:self action:@selector(stopReading) forControlEvents:UIControlEventTouchUpInside];
    [_qrcodeViewController.view addSubview:_buttonStop];

    _captureSession = nil;
    _isReading = NO;
    
}

- (void) rotate:(NSNotification *) notification{
    if(UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation])){
        // NSLog(@"portrait");
        height = portraitheight;
        width  = landscapeheight;
    }
    else if (UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation])) {
        // NSLog(@"landscape");
        height = landscapeheight;
        width  = portraitheight;
    }
    // NSLog(@"w: %f, h: %f",width, height);
    
    _qrcodeview.frame = CGRectMake(0, 0, width, height) ;
    _viewPreview.frame = CGRectMake(0, 0, width, height) ;
    _buttonStop.frame =  CGRectMake(0, height-64, width, 64);
    [_videoPreviewLayer setFrame:_viewPreview.layer.bounds];
    [_qrcodeViewController viewWillLayoutSubviews];

}

- (void)didReceiveMemoryWarning {
    //[super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)startReading {
    if (_isReading) return NO;
    _isReading = YES;

    NSError *error;
    
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (!input) {
        NSLog(@"%@", [error localizedDescription]);
        return NO;
    }
    
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession addInput:input];
    
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [_captureSession addOutput:captureMetadataOutput];
    
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create("myQueue", NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    
    _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [_videoPreviewLayer setFrame:_viewPreview.layer.bounds];
    [_viewPreview.layer addSublayer:_videoPreviewLayer];
    
    [_captureSession startRunning];
    return YES;
}


-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
           // NSLog(@"result of scan: %@", [metadataObj stringValue]);
            _result([metadataObj stringValue]);
            [self performSelectorOnMainThread:@selector(stopReading) withObject:nil waitUntilDone:NO];
            _isReading = NO;
            
        }
    }
}

-(void)stopReading{
    [_captureSession stopRunning];
    _captureSession = nil;
    [_videoPreviewLayer removeFromSuperlayer];
    _isReading = NO;
    [self closeQRCodeView];
    _result(@"");
}




@end



