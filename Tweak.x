#import <UIKit/UIKit.h>
#import <substrate.h>

// 定義 MapleStory M 的 Bundle ID
#define MAPLEM_BUNDLE_ID @"com.nexon.maplem.global"

// 聲明 UIApplication 的 bundleIdentifier 屬性，防止編譯錯誤
@interface UIApplication (Private)
- (NSString *)bundleIdentifier;
@end

// 自定義的 UI 類別，用於顯示菜單或提示
@interface MapleStoryMGlobalToast : NSObject
+ (instancetype)sharedInstance;
- (void)showToastWithMessage:(NSString *)message duration:(NSTimeInterval)duration;
- (void)showMenu;
- (void)hideMenu;
- (void)addMenuSwitchWithTitle:(NSString *)title action:(SEL)action;
- (void)addMenuButtonWithTitle:(NSString *)title action:(SEL)action;
@end

@implementation MapleStoryMGlobalToast {
    UIWindow *_overlayWindow;
    UILabel *_messageLabel;
    UIButton *_menuButton;
    UIView *_menuView;
    BOOL _menuVisible;
    CGFloat _menuItemYOffset;
}

+ (instancetype)sharedInstance {
    static MapleStoryMGlobalToast *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        _overlayWindow.backgroundColor = [UIColor clearColor];
        _overlayWindow.hidden = YES;

        _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, _overlayWindow.bounds.size.width - 40, 40)];
        _messageLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
        _messageLabel.textColor = [UIColor whiteColor];
        _messageLabel.textAlignment = NSTextAlignmentCenter;
        _messageLabel.layer.cornerRadius = 5;
        _messageLabel.clipsToBounds = YES;
        _messageLabel.alpha = 0.0;
        [_overlayWindow addSubview:_messageLabel];

        _menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _menuButton.frame = CGRectMake(_overlayWindow.bounds.size.width - 60, 60, 50, 50);
        [_menuButton setTitle:@"Menu" forState:UIControlStateNormal];
        [_menuButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        _menuButton.backgroundColor = [UIColor blueColor];
        _menuButton.layer.cornerRadius = 25;
        _menuButton.clipsToBounds = YES;
        [_overlayWindow addSubview:_menuButton];

        _menuView = [[UIView alloc] initWithFrame:CGRectMake(_overlayWindow.bounds.size.width - 220, 120, 200, 300)];
        _menuView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
        _menuView.layer.cornerRadius = 10;
        _menuView.clipsToBounds = YES;
        _menuView.hidden = YES;
        [_overlayWindow addSubview:_menuView];

        _menuVisible = NO;
        _menuItemYOffset = 10.0;
    }
    return self;
}

- (void)showToastWithMessage:(NSString *)message duration:(NSTimeInterval)duration {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_messageLabel.text = message;
        self->_overlayWindow.hidden = NO;
        [UIView animateWithDuration:0.3 animations:^{
            self->_messageLabel.alpha = 1.0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3 delay:duration options:UIViewAnimationOptionCurveEaseOut animations:^{
                self->_messageLabel.alpha = 0.0;
            } completion:^(BOOL finished) {
                if (self->_menuView.hidden && self->_messageLabel.alpha == 0.0) {
                    self->_overlayWindow.hidden = YES;
                }
            }];
        }];
    });
}

- (void)toggleMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_menuVisible = !self->_menuVisible;
        self->_menuView.hidden = !self->_menuVisible;
        self->_overlayWindow.hidden = !self->_menuVisible && self->_messageLabel.alpha == 0.0;
    });
}

- (void)showMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_menuVisible = YES;
        self->_menuView.hidden = NO;
        self->_overlayWindow.hidden = NO;
    });
}

- (void)hideMenu {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_menuVisible = NO;
        self->_menuView.hidden = YES;
        if (self->_messageLabel.alpha == 0.0) {
            self->_overlayWindow.hidden = YES;
        }
    });
}

- (void)addMenuSwitchWithTitle:(NSString *)title action:(SEL)action {
    dispatch_async(dispatch_get_main_queue(), ^{
        UISwitch *menuSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(self->_menuView.bounds.size.width - 60, self->_menuItemYOffset, 0, 0)];
        [menuSwitch addTarget:self action:action forControlEvents:UIControlEventValueChanged];
        [self->_menuView addSubview:menuSwitch];

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, self->_menuItemYOffset, self->_menuView.bounds.size.width - 70, 30)];
        titleLabel.text = title;
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = [UIFont systemFontOfSize:14];
        [self->_menuView addSubview:titleLabel];

        self->_menuItemYOffset += 40.0;
    });
}

- (void)addMenuButtonWithTitle:(NSString *)title action:(SEL)action {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
        menuButton.frame = CGRectMake(10, self->_menuItemYOffset, self->_menuView.bounds.size.width - 20, 30);
        [menuButton setTitle:title forState:UIControlStateNormal];
        [menuButton addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
        menuButton.backgroundColor = [UIColor darkGrayColor];
        menuButton.layer.cornerRadius = 5;
        menuButton.clipsToBounds = YES;
        [menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self->_menuView addSubview:menuButton];

        self->_menuItemYOffset += 40.0;
    });
}

- (void)exampleSwitchChanged:(UISwitch *)sender {
    [self showToastWithMessage:[NSString stringWithFormat:@"Feature: %@", sender.on ? @"ON" : @"OFF"] duration:1.5];
}

- (void)exampleButtonPressed {
    [self showToastWithMessage:@"Action Triggered!" duration:1.5];
}

@end

%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL ret = %orig;
    
    // 使用 NSString 比較
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    if ([bundleID isEqualToString:MAPLEM_BUNDLE_ID]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            MapleStoryMGlobalToast *toast = [MapleStoryMGlobalToast sharedInstance];
            [toast showMenu];
            [toast showToastWithMessage:@"MapleStory M Global Loaded!" duration:3.0];
            
            [toast addMenuSwitchWithTitle:@"無限藥水" action:@selector(exampleSwitchChanged:)];
            [toast addMenuSwitchWithTitle:@"自動打怪" action:@selector(exampleSwitchChanged:)];
            [toast addMenuButtonWithTitle:@"傳送至指定地點" action:@selector(exampleButtonPressed)];
        });
    }
    return ret;
}

%end
