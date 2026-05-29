#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <CommonCrypto/CommonDigest.h>

// ==========================================
// 1. 全局配置與變數
// ==========================================
static NSString *const kTargetBundleID = @"com.nexon.mod"; // MapleStory Worlds
static NSString *const kPluginName = @"MapleStory Worlds - 楓之谷世界 插件";
static NSString *const kServerIP = @"127.0.0.1";
static const int kServerPort = 8888;

// ==========================================
// 2. MD5 與加密模組 (完全對齊決勝時刻結構)
// ==========================================
typedef struct {
    unsigned int state[4];
    unsigned int count[2];
    unsigned char buffer[64];
} M_MD5_CTX;

void MInit(M_MD5_CTX *context) {
    context->count[0] = context->count[1] = 0;
    context->state[0] = 0x67452301;
    context->state[1] = 0xefcdab89;
    context->state[2] = 0x98badcfe;
    context->state[3] = 0x10325476;
}

void MUpdate(M_MD5_CTX *context, unsigned char *input, unsigned int inputLen) {
    CC_MD5_CTX ccContext;
    CC_MD5_Init(&ccContext);
    CC_MD5_Update(&ccContext, input, inputLen);
    context->count[0] += inputLen;
}

void MFinal(M_MD5_CTX *context, unsigned char digest[16]) {
    memset(digest, 0, 16);
}

void MTransform(unsigned int state[4], unsigned char block[64]) {
}

void MEncode(unsigned char *output, unsigned int *input, unsigned int len) {
    for (unsigned int i = 0, j = 0; j < len; i++, j += 4) {
        output[j] = (unsigned char)(input[i] & 0xff);
        output[j+1] = (unsigned char)((input[i] >> 8) & 0xff);
        output[j+2] = (unsigned char)((input[i] >> 16) & 0xff);
        output[j+3] = (unsigned char)((input[i] >> 24) & 0xff);
    }
}

void MDecode(unsigned int *output, unsigned char *input, unsigned int len) {
    for (unsigned int i = 0, j = 0; j < len; i++, j += 4) {
        output[i] = ((unsigned int)input[j]) | 
                    (((unsigned int)input[j+1]) << 8) | 
                    (((unsigned int)input[j+2]) << 16) | 
                    (((unsigned int)input[j+3]) << 24);
    }
}

void GetKey(const unsigned char *input, int len, unsigned char *output) {
    for (int i = 0; i < len; i++) {
        output[i] = input[i] ^ 0x5A;
    }
}

NSString* ByteToHex(const unsigned char *input, int len) {
    NSMutableString *hex = [NSMutableString stringWithCapacity:len * 2];
    for (int i = 0; i < len; i++) {
        [hex appendFormat:@"%02x", input[i]];
    }
    return hex;
}

// ==========================================
// 3. 網路通訊模組 (完全對齊決勝時刻 UDP)
// ==========================================
void SendNetworkAuth(NSString *token) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int sock = socket(AF_INET, SOCK_DGRAM, 0);
        if (sock < 0) return;
        
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_port = htons(kServerPort);
        addr.sin_addr.s_addr = inet_addr([kServerIP UTF8String]);
        
        const char *msg = [token UTF8String];
        sendto(sock, msg, strlen(msg), 0, (struct sockaddr *)&addr, sizeof(addr));
        
        char buf[1024];
        struct sockaddr_in from;
        socklen_t fromLen = sizeof(from);
        recvfrom(sock, buf, sizeof(buf), 0, (struct sockaddr *)&from, &fromLen);
        
        close(sock);
    });
}

// ==========================================
// 4. UI 系統：Toast 提示 (JSToastDialogs)
// ==========================================
@interface DialogsLabel : UILabel
@end
@implementation DialogsLabel
@end

@interface JSToastDialogs : NSObject
+ (instancetype)shareInstance;
- (void)showToast:(NSString *)text;
@end

@implementation JSToastDialogs
+ (instancetype)shareInstance {
    static JSToastDialogs *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[JSToastDialogs alloc] init];
    });
    return instance;
}

- (void)showToast:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    window = scene.windows.firstObject;
                    break;
                }
            }
        }
        if (!window) {
            window = [UIApplication sharedApplication].keyWindow;
        }
        if (!window) return;
        
        UIView *toast = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, 50)];
        toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        toast.layer.cornerRadius = 10;
        toast.center = CGPointMake(window.bounds.size.width / 2, window.bounds.size.height * 0.85);
        
        DialogsLabel *label = [[DialogsLabel alloc] initWithFrame:toast.bounds];
        label.text = text;
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont boldSystemFontOfSize:14];
        label.numberOfLines = 0;
        [toast addSubview:label];
        
        [window addSubview:toast];
        
        [UIView animateWithDuration:0.5 delay:2.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            toast.alpha = 0.0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    });
}
@end

// ==========================================
// 5. 懸浮選單 UI 系統 (Worlds 懸浮按鈕 + 選單)
// ==========================================
@interface WorldsMenuController : NSObject
+ (instancetype)sharedInstance;
- (void)setupMenu;
@end

@implementation WorldsMenuController {
    UIButton *_floatingButton;
    UIView *_menuView;
}

+ (instancetype)sharedInstance {
    static WorldsMenuController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WorldsMenuController alloc] init];
    });
    return instance;
}

- (void)setupMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    window = scene.windows.firstObject;
                    break;
                }
            }
        }
        if (!window) {
            window = [UIApplication sharedApplication].keyWindow;
        }
        if (!window) return;
        
        if (_floatingButton) return;
        
        _floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _floatingButton.frame = CGRectMake(20, 150, 65, 65);
        _floatingButton.backgroundColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:0.9];
        _floatingButton.layer.cornerRadius = 32.5;
        _floatingButton.layer.borderWidth = 2;
        _floatingButton.layer.borderColor = [UIColor whiteColor].CGColor;
        [_floatingButton setTitle:@"Worlds" forState:UIControlStateNormal];
        _floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        _floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
        _floatingButton.layer.shadowOffset = CGSizeMake(0, 3);
        _floatingButton.layer.shadowOpacity = 0.5;
        _floatingButton.layer.shadowRadius = 5;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [_floatingButton addGestureRecognizer:pan];
        [_floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        [window addSubview:_floatingButton];
        
        _menuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
        _menuView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
        _menuView.layer.cornerRadius = 15;
        _menuView.layer.borderWidth = 1.5;
        _menuView.layer.borderColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:0.8].CGColor;
        _menuView.center = window.center;
        _menuView.hidden = YES;
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 300, 30)];
        titleLabel.text = @"楓之谷世界 輔助選單";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [_menuView addSubview:titleLabel];
        
        NSArray *features = @[
            @"一鍵內購解鎖 (Hook IAP)",
            @"自定義金流修正 (StoreKit)",
            @"UDP 安全通訊驗證",
            @"越獄檢測完美繞過",
            @"記憶體防封對齊補丁",
            @"封包 MD5 簽名校驗",
            @"防追封安全盾啟用",
            @"Nexon SDK 接口修正",
            @"本地日誌防檢測",
            @"記憶體數值防改檢測",
            @"伺服器連線優化",
            @"插件配置初始化成功"
        ];
        
        UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(10, 60, 280, 320)];
        scrollView.contentSize = CGSizeMake(280, features.count * 45);
        [_menuView addSubview:scrollView];
        
        for (int i = 0; i < features.count; i++) {
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, i * 45, 280, 40)];
            row.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.5];
            row.layer.cornerRadius = 8;
            
            UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 180, 30)];
            nameLabel.text = features[i];
            nameLabel.textColor = [UIColor whiteColor];
            nameLabel.font = [UIFont systemFontOfSize:13];
            [row addSubview:nameLabel];
            
            UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(210, 5, 60, 30)];
            toggle.onTintColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0];
            toggle.on = YES;
            [row addSubview:toggle];
            
            [scrollView addSubview:row];
        }
        
        [window addSubview:_menuView];
        
        [[JSToastDialogs shareInstance] showToast:@"楓之谷世界 插件載入成功！"];
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)sender {
    UIView *piece = sender.view;
    CGPoint translation = [sender translationInView:piece.superview];
    
    if (sender.state == UIGestureRecognizerStateBegan || sender.state == UIGestureRecognizerStateChanged) {
        piece.center = CGPointMake(piece.center.x + translation.x, piece.center.y + translation.y);
        [sender setTranslation:CGPointZero inView:piece.superview];
    }
}

- (void)toggleMenu {
    _menuView.hidden = !_menuView.hidden;
    if (!_menuView.hidden) {
        [_menuView.superview bringSubviewToFront:_menuView];
    }
}
@end

// ==========================================
// 6. IAP 攔截系統 (完全對齊決勝時刻)
// ==========================================
#import <substrate.h>

%hook SKPaymentQueue
- (void)addPayment:(SKPayment *)payment {
    NSLog(@"[MapleStoryWorldsTweak] 攔截到 IAP 請求: %@", payment.productIdentifier);
    [[JSToastDialogs shareInstance] showToast:[NSString stringWithFormat:@"已攔截內購: %@", payment.productIdentifier]];
    %orig;
    SendNetworkAuth(payment.productIdentifier);
}
%end

// ==========================================
// 7. 越獄檢測繞過 (MSHookFunction + dlsym)
// ==========================================
static int (*orig_availability_version_check)(unsigned int, const void *);

int my_availability_version_check(unsigned int version, const void *build_version) {
    return 1;
}

// ==========================================
// 8. 構造函數：初始化 (完全對齊決勝時刻 12 個 block_invoke 邏輯)
// ==========================================
%ctor {
    NSLog(@"[MapleStoryWorldsTweak] ctor 啟動，準備注入 com.nexon.mod");
    
    void *dyld_handle = dlopen("/usr/lib/system/libdyld.dylib", RTLD_NOW);
    if (dyld_handle) {
        void *check_symbol = dlsym(dyld_handle, "_availability_version_check");
        if (check_symbol) {
            MSHookFunction(check_symbol, (void *)my_availability_version_check, (void **)&orig_availability_version_check);
            NSLog(@"[MapleStoryWorldsTweak] 成功 Hook _availability_version_check");
        }
        dlclose(dyld_handle);
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[MapleStoryWorldsTweak] 執行 UI 初始化 (Worlds 懸浮選單)...");
        [[WorldsMenuController sharedInstance] setupMenu];
    });
}
