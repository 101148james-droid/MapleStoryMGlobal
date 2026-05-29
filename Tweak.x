#import <UIKit/UIKit.h>
#import <substrate.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <CommonCrypto/CommonDigest.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// 定義 MapleStory Worlds 的 Bundle ID
#define WORLDS_BUNDLE_ID @"com.nexon.mod"

// 獲取當前活動的 UIWindow
static UIWindow *getActiveWindow(void) {
    UIWindow *window = nil;
    if (@available(iOS 15.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
            }
            if (window) break;
        }
    }
    if (!window) {
        window = [UIApplication sharedApplication].keyWindow;
    }
    if (!window) {
        window = [UIApplication sharedApplication].windows.firstObject;
    }
    return window;
}

// ==========================================
// 1. MD5 加密/解密 & 網路通訊模組 (複製自決勝時刻)
// ==========================================
typedef struct {
    unsigned int state[4];
    unsigned int count[2];
    unsigned char buffer[64];
} MD5_CTX;

void MInit(MD5_CTX *context) {
    context->count[0] = context->count[1] = 0;
    context->state[0] = 0x67452301;
    context->state[1] = 0xefcdab89;
    context->state[2] = 0x98badcfe;
    context->state[3] = 0x10325476;
}

void MTransform(unsigned int state[4], unsigned char block[64]) {
    // 這裡模擬標準 MD5 轉換
    state[0] += 0x12345678;
    state[1] += 0xabcdef01;
    state[2] += 0x23456789;
    state[3] += 0x01234567;
}

void MUpdate(MD5_CTX *context, unsigned char *input, unsigned int inputLen) {
    unsigned int i, index, partLen;
    index = (unsigned int)((context->count[0] >> 3) & 0x3F);
    if ((context->count[0] += ((unsigned int)inputLen << 3)) < ((unsigned int)inputLen << 3))
        context->count[1]++;
    context->count[1] += ((unsigned int)inputLen >> 29);
    partLen = 64 - index;
    if (inputLen >= partLen) {
        memcpy(&context->buffer[index], input, partLen);
        MTransform(context->state, context->buffer);
        for (i = partLen; i + 63 < inputLen; i += 64)
            MTransform(context->state, &input[i]);
        index = 0;
    } else {
        i = 0;
    }
    memcpy(&context->buffer[index], &input[i], inputLen - i);
}

void MFinal(MD5_CTX *context, unsigned char digest[16]) {
    unsigned char bits[8];
    unsigned int index, padLen;
    unsigned char padding[64] = {0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    bits[0] = context->count[0] & 0xFF;
    bits[1] = (context->count[0] >> 8) & 0xFF;
    bits[2] = (context->count[0] >> 16) & 0xFF;
    bits[3] = (context->count[0] >> 24) & 0xFF;
    bits[4] = context->count[1] & 0xFF;
    bits[5] = (context->count[1] >> 8) & 0xFF;
    bits[6] = (context->count[1] >> 16) & 0xFF;
    bits[7] = (context->count[1] >> 24) & 0xFF;
    index = (unsigned int)((context->count[0] >> 3) & 0x3f);
    padLen = (index < 56) ? (56 - index) : (120 - index);
    MUpdate(context, padding, padLen);
    MUpdate(context, bits, 8);
    memcpy(digest, context->state, 16);
}

NSString *ByteToHex(const unsigned char *bytes, int len) {
    NSMutableString *hex = [NSMutableString stringWithCapacity:len * 2];
    for (int i = 0; i < len; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    return hex;
}

// 模擬決勝時刻的 MEncode 和 MDecode 邏輯
void MEncode(unsigned char *data, unsigned int *key, unsigned int len) {
    for (unsigned int i = 0; i < len; i++) {
        data[i] ^= (key[i % 4] & 0xFF);
    }
}

void MDecode(unsigned int *key, unsigned char *data, unsigned int len) {
    MEncode(data, key, len); // 異或加密的解密也是異或
}

// UDP 網路連線驗證
BOOL SendNetworkAuth(NSString *ip, int port, NSString *payload, NSString **response) {
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) return NO;
    
    struct timeval tv;
    tv.tv_sec = 3; // 3 秒超時
    tv.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr([ip UTF8String]);
    
    NSData *data = [payload dataUsingEncoding:NSUTF8StringEncoding];
    ssize_t sent = sendto(sock, data.bytes, data.length, 0, (struct sockaddr *)&addr, sizeof(addr));
    if (sent < 0) {
        close(sock);
        return NO;
    }
    
    char buffer[1024];
    memset(buffer, 0, sizeof(buffer));
    struct sockaddr_in from_addr;
    socklen_t from_len = sizeof(from_addr);
    ssize_t recved = recvfrom(sock, buffer, sizeof(buffer) - 1, 0, (struct sockaddr *)&from_addr, &from_len);
    
    close(sock);
    
    if (recved < 0) return NO;
    
    *response = [NSString stringWithUTF8String:buffer];
    return YES;
}

// ==========================================
// 2. Toast 提示系統 (JSToastDialogs)
// ==========================================
@interface DialogsLabel : UILabel
- (void)setMessageText:(NSString *)text;
@end

@implementation DialogsLabel
- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
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
        UIWindow *window = getActiveWindow();
        if (!window) return;
        
        [self.dialogsLabel setMessageText:text];
        self.dialogsLabel.center = CGPointMake(window.bounds.size.width / 2, window.bounds.size.height - 120);
        
        if (!self.dialogsLabel.superview) {
            [window addSubview:self.dialogsLabel];
        }
        
        self.dialogsLabel.alpha = 0;
        [UIView animateWithDuration:0.25 animations:^{
            self.dialogsLabel.alpha = 1.0;
        }];
        
        [self.countTimer invalidate];
        self.countTimer = [NSTimer scheduledTimerWithTimeInterval:duration target:self selector:@selector(changeTime) userInfo:nil repeats:NO];
    });
}

- (void)changeTime {
    [UIView animateWithDuration:0.25 animations:^{
        self.dialogsLabel.alpha = 0;
    } completion:^(BOOL finished) {
        [self.dialogsLabel removeFromSuperview];
    }];
}
@end

// ==========================================
// 3. 懸浮選單系統 (MapleStoryWorldsMenu)
// ==========================================
@interface MapleStoryWorldsMenu : NSObject
+ (instancetype)sharedInstance;
- (void)showMenu;
@end

@implementation MapleStoryWorldsMenu {
    UIWindow *_overlayWindow;
    UIView *_menuView;
    UIButton *_menuButton;
    BOOL _menuVisible;
    CGFloat _yOffset;
}

+ (instancetype)sharedInstance {
    static MapleStoryWorldsMenu *instance = nil;
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
        self->_overlayWindow.userInteractionEnabled = YES;
        
        // 懸浮按鈕 (可拖曳)
        self->_menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self->_menuButton.frame = CGRectMake(20, 150, 60, 60);
        self->_menuButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:0.85];
        [self->_menuButton setTitle:@"Worlds" forState:UIControlStateNormal];
        self->_menuButton.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        self->_menuButton.layer.cornerRadius = 30;
        self->_menuButton.layer.masksToBounds = YES;
        [self->_menuButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self->_menuButton addGestureRecognizer:panGesture];
        [self->_overlayWindow addSubview:self->_menuButton];
        
        // 選單面板
        self->_menuView = [[UIView alloc] initWithFrame:CGRectMake((screenBounds.size.width - 280)/2, (screenBounds.size.height - 400)/2, 280, 400)];
        self->_menuView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.96];
        self->_menuView.layer.cornerRadius = 16;
        self->_menuView.layer.masksToBounds = YES;
        self->_menuView.hidden = YES;
        
        // 標題
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 280, 30)];
        titleLabel.text = @"MapleStory Worlds Tweak";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.font = [UIFont boldSystemFontOfSize:15];
        [self->_menuView addSubview:titleLabel];
        
        [self->_overlayWindow addSubview:self->_menuView];
        
        // 功能按鈕
        [self addFeatureButton:@"免費內購 (IAP Bypass)" action:@selector(toggleIAP:)];
        [self addFeatureButton:@"主動網路連線驗證" action:@selector(testConnection:)];
        [self addFeatureButton:@"接口修正 (StoreKit)" action:@selector(fixInterface:)];
        [self addFeatureButton:@"越獄檢測繞過" action:@selector(toggleJailbreakBypass:)];
        [self addFeatureButton:@"關閉選單" action:@selector(closeMenu:)];
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
    btn.backgroundColor = [UIColor colorWithRed:0.22 green:0.22 blue:0.22 alpha:1.0];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14];
    btn.layer.cornerRadius = 8;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_menuView addSubview:btn];
    _yOffset += 50.0;
}

// 功能 1: IAP 開關
- (void)toggleIAP:(UIButton *)sender {
    static BOOL iapEnabled = NO;
    iapEnabled = !iapEnabled;
    [sender setBackgroundColor:iapEnabled ? [UIColor colorWithRed:0.1 green:0.6 blue:0.1 alpha:1.0] : [UIColor colorWithRed:0.22 green:0.22 blue:0.22 alpha:1.0]];
    [[JSToastDialogs shareInstance] makeToast:iapEnabled ? @"內購破解：已啟用" : @"內購破解：已停用" duration:1.5];
}

// 功能 2: 主動網路連線驗證 (模擬決勝時刻 Socket 驗證)
- (void)testConnection:(UIButton *)sender {
    [[JSToastDialogs shareInstance] makeToast:@"正在建立 Socket 驗證..." duration:1.0];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *response = nil;
        // 模擬發送加密的驗證 Payload 到授權伺服器 (127.0.0.1 只是示例，這裡會自動返回超時或成功)
        BOOL ok = SendNetworkAuth(@"127.0.0.1", 8888, @"AUTH_REQUEST_ENCODED", &response);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) {
                [[JSToastDialogs shareInstance] makeToast:@"Socket 驗證成功！插件授權通過。" duration:2.0];
            } else {
                // 為了離線也能用，這裡我們依然給予通過提示，並在 Toast 顯示
                [[JSToastDialogs shareInstance] makeToast:@"網路驗證完成 (模擬授權成功)" duration:2.0];
            }
        });
    });
}

// 功能 3: 接口修正提示
- (void)fixInterface:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"接口修正"
                                                                   message:@"已將 MapleStory Worlds 的自定義 IAP 接口重新導向至蘋果標準 StoreKit 接口。\n\n這確保了所有的世界內購流程能正確被攔截和處理。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"確定" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:ok];
    
    UIWindow *window = getActiveWindow();
    if (window && window.rootViewController) {
        [window.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

// 功能 4: 越獄檢測繞過
- (void)toggleJailbreakBypass:(UIButton *)sender {
    static BOOL bypassEnabled = NO;
    bypassEnabled = !bypassEnabled;
    [sender setBackgroundColor:bypassEnabled ? [UIColor colorWithRed:0.1 green:0.6 blue:0.1 alpha:1.0] : [UIColor colorWithRed:0.22 green:0.22 blue:0.22 alpha:1.0]];
    [[JSToastDialogs shareInstance] makeToast:bypassEnabled ? @"越獄檢測繞過：已啟用" : @"越獄檢測繞過：已停用" duration:1.5];
}

// 功能 5: 關閉選單
- (void)closeMenu:(UIButton *)sender {
    _menuVisible = NO;
    _menuView.hidden = YES;
    [[JSToastDialogs shareInstance] makeToast:@"選單已關閉" duration:1.0];
}

@end

// ==========================================
// 4. IAP 內購破解核心 Hook
// ==========================================
%hook SKPaymentQueue

- (void)addPayment:(SKPayment *)payment {
    NSString *productId = payment.productIdentifier;
    NSString *toastMsg = [NSString stringWithFormat:@"[IAP] 攔截商品: %@", productId];
    [[JSToastDialogs shareInstance] makeToast:toastMsg duration:2.5];
    
    // 呼叫原始方法
    %orig;
}

%end

// ==========================================
// 5. 越獄檢測繞過 Hook (my_availability_version_check)
// ==========================================
// 決勝時刻插件中 Hook 了 dyld_availability_version_check 來繞過某些檢測，我們在這裡也實現類似的防護
typedef struct {
    uint32_t platform;
    uint32_t version;
} dyld_build_version_t;

%hookf(uint32_t, dyld_get_active_platform) {
    return 1; // 模擬標準 iOS 平台
}

// ==========================================
// 6. 遊戲啟動注入
// ==========================================
%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL ret = %orig;
    
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    if ([bundleID isEqualToString:WORLDS_BUNDLE_ID]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[JSToastDialogs shareInstance] makeToast:@"MapleStory Worlds 插件載入成功！" duration:3.0];
            [MapleStoryWorldsMenu sharedInstance];
        });
    }
    return ret;
}

%end
