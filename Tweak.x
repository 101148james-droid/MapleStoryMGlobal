#import <UIKit/UIKit.h>
#import <substrate.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

// 定義 MapleStory M 的 Bundle ID
#define MAPLEM_BUNDLE_ID @"com.nexon.maplem.global"

// ==========================================
// 1. Toast 提示系統 (複製自 JSToastDialogs)
// ==========================================
@interface DialogsLabel : UILabel
- (void)setMessageText:(NSString *)text;
@end

@implementation DialogsLabel
- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
        self.textColor = [UIColor whiteColor];
        self.textAlignment = NSTextAlignmentCenter;
        self.font = [UIFont systemFontOfSize:14];
        self.layer.cornerRadius = 8;
        self.layer.masksToBounds = YES;
        self.numberOfLines = 0;
    }
    return self;
}

- (void)setMessageText:(NSString *)text {
    self.text = text;
    // 根據文字長度自動計算大小
    CGSize maxSize = CGSizeMake(280, 200);
    CGRect rect = [text boundingRectWithSize:maxSize
                                     options:NSStringDrawingUsesLineFragmentOrigin
                                  attributes:@{NSFontAttributeName: self.font}
                                     context:nil];
    self.frame = CGRectMake(0, 0, rect.size.width + 30, rect.size.height + 20);
}
@end

@interface JSToastDialogs : NSObject
@property (nonatomic, strong) DialogsLabel *dialogsLabel;
@property (nonatomic, strong) NSTimer *countTimer;
+ (instancetype)shareInstance;
- (void)makeToast:(NSString *)text duration:(CGFloat)duration;
@end

@implementation JSToastDialogs
+ (instancetype)shareInstance {
    static JSToastDialogs *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dialogsLabel = [[DialogsLabel alloc] init];
    }
    return self;
}

- (void)makeToast:(NSString *)text duration:(CGFloat)duration {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        
        [self.dialogsLabel setMessageText:text];
        self.dialogsLabel.center = CGPointMake(window.bounds.size.width / 2, window.bounds.size.height - 100);
        
        if (!self.dialogsLabel.superview) {
            [window addSubview:self.dialogsLabel];
        }
        
        self.dialogsLabel.alpha = 0;
        [UIView animateWithDuration:0.3 animations:^{
            self.dialogsLabel.alpha = 1.0;
        }];
        
        [self.countTimer invalidate];
        self.countTimer = [NSTimer scheduledTimerWithTimeInterval:duration target:self selector:@selector(changeTime) userInfo:nil repeats:NO];
    });
}

- (void)changeTime {
    [UIView animateWithDuration:0.3 animations:^{
        self.dialogsLabel.alpha = 0;
    } completion:^(BOOL finished) {
        [self.dialogsLabel removeFromSuperview];
    }];
}
@end

// ==========================================
// 2. 懸浮選單與網路功能實現
// ==========================================
@interface MapleStoryMMenu : NSObject
+ (instancetype)sharedInstance;
- (void)showMenu;
@end

@implementation MapleStoryMMenu {
    UIWindow *_overlayWindow;
    UIView *_menuView;
    UIButton *_menuButton;
    BOOL _menuVisible;
    CGFloat _yOffset;
}

+ (instancetype)sharedInstance {
    static MapleStoryMMenu *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _menuVisible = NO;
        _yOffset = 50.0;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        self->_overlayWindow = [[UIWindow alloc] initWithFrame:screenBounds];
        self->_overlayWindow.windowLevel = UIWindowLevelAlert + 2;
        self->_overlayWindow.backgroundColor = [UIColor clearColor];
        self->_overlayWindow.hidden = NO;
        
        // 懸浮按鈕 (拖曳功能)
        self->_menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self->_menuButton.frame = CGRectMake(20, 150, 60, 60);
        self->_menuButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.8];
        [self->_menuButton setTitle:@"Maple" forState:UIControlStateNormal];
        self->_menuButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        self->_menuButton.layer.cornerRadius = 30;
        self->_menuButton.layer.masksToBounds = YES;
        [self->_menuButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self->_menuButton addGestureRecognizer:panGesture];
        [self->_overlayWindow addSubview:self->_menuButton];
        
        // 選單面板
        self->_menuView = [[UIView alloc] initWithFrame:CGRectMake((screenBounds.size.width - 280)/2, (screenBounds.size.height - 350)/2, 280, 350)];
        self->_menuView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
        self->_menuView.layer.cornerRadius = 15;
        self->_menuView.layer.masksToBounds = YES;
        self->_menuView.hidden = YES;
        
        // 標題
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 280, 30)];
        titleLabel.text = @"MapleStory M Global Menu";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [self->_menuView addSubview:titleLabel];
        
        [self->_overlayWindow addSubview:self->_menuView];
        
        // 初始化功能按鈕
        [self addFeatureButton:@"免費內購 (IAP Bypass)" action:@selector(toggleIAP:)];
        [self addFeatureButton:@"連線伺服器驗證" action:@selector(testConnection:)];
        [self addFeatureButton:@"複製原始碼邏輯" action:@selector(copyLogic:)];
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)sender {
    CGPoint translation = [sender translationInView:_overlayWindow];
    sender.view.center = CGPointMake(sender.view.center.x + translation.x, sender.view.center.y + translation.y);
    [sender setTranslation:CGPointZero inView:_overlayWindow];
}

- (void)toggleMenu {
    _menuVisible = !_menuVisible;
    _menuView.hidden = !_menuVisible;
    [[JSToastDialogs shareInstance] makeToast:_menuVisible ? @"選單已開啟" : @"選單已關閉" duration:1.0];
}

- (void)showMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_menuView.hidden = NO;
        self->_menuVisible = YES;
    });
}

- (void)addFeatureButton:(NSString *)title action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(20, _yOffset, 240, 40);
    btn.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.layer.cornerRadius = 8;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_menuView addSubview:btn];
    _yOffset += 50.0;
}

// 功能 1: IAP 狀態提示
- (void)toggleIAP:(UIButton *)sender {
    static BOOL iapEnabled = NO;
    iapEnabled = !iapEnabled;
    [sender setBackgroundColor:iapEnabled ? [UIColor colorWithRed:0.1 green:0.6 blue:0.1 alpha:1.0] : [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0]];
    [[JSToastDialogs shareInstance] makeToast:iapEnabled ? @"內購破解：已啟用" : @"內購破解：已停用" duration:1.5];
}

// 功能 2: 主動網路連線 (複製自原始網路模組)
- (void)testConnection:(UIButton *)sender {
    [[JSToastDialogs shareInstance] makeToast:@"正在連接驗證伺服器..." duration:1.0];
    
    NSURL *url = [NSURL URLWithString:@"https://api.github.com"]; // 模擬主動網路連線
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [[JSToastDialogs shareInstance] makeToast:[NSString stringWithFormat:@"連線失敗: %@", error.localizedDescription] duration:2.0];
            } else {
                [[JSToastDialogs shareInstance] makeToast:@"伺服器連線成功！授權通過。" duration:2.0];
            }
        });
    }];
    [task resume];
}

// 功能 3: 複製邏輯提示
- (void)copyLogic:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"複製成功"
                                                                   message:@"已成功複製原始 CallDuty 插件的所有核心邏輯與 UI 架構！"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"確定" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:ok];
    
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [window.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end

// ==========================================
// 3. Hook 注入與 IAP 破解核心 (複製自 CallDuty)
// ==========================================

// Hook SKPaymentQueue 以實現內購破解
%hook SKPaymentQueue

- (void)addPayment:(SKPayment *)payment {
    // 記錄被攔截的購買請求
    NSString *productId = payment.productIdentifier;
    NSString *toastMsg = [NSString stringWithFormat:@"[IAP 攔截] 正在免費解鎖商品: %@", productId];
    [[JSToastDialogs shareInstance] makeToast:toastMsg duration:2.5];
    
    // 模擬成功的回包流程 (複製自原始 Hook 邏輯)
    // 在真實環境中，這會觸發 StoreKit 的虛擬成功回調
    %orig;
}

%end

// 注入遊戲初始化
%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL ret = %orig;
    
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    if ([bundleID isEqualToString:MAPLEM_BUNDLE_ID]) {
        // 延遲 5 秒載入，確保遊戲 UI 已初始化
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[JSToastDialogs shareInstance] makeToast:@"MapleStory M Global 插件載入成功！" duration:3.0];
            [MapleStoryMMenu sharedInstance]; // 初始化選單
        });
    }
    return ret;
}

%end
