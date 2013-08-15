//
//  OTNotificationWindow.m
//  OTNotificationViewDemo
//
//  Created by openthread on 8/12/13.
//
//

#import "OTNotificationWindow.h"
#import "OTCubeRotateView.h"
#import "OTScreenshotHelper.h"
#import "OTNotificationContentView.h"
#import "OTMessageNotificationView.h"

typedef enum {
    OTNotificationWindowStateHidden,//Hidding
    OTNotificationWindowStateCubeRotatingIn,//Rotating in
    OTNotificationWindowStateShowing,//Showing
    OTNotificationWindowStateWaitingCubeRotatingOut,
    OTNotificationWindowStateCubeRotatingOut//Rotating out
} OTNotificationWindowState;

@interface OTNotificationWindow() <ComOpenthreadOTNotificationRotateWindowDelegate>
@property (nonatomic, assign) OTNotificationWindowState state;
@end

@implementation OTNotificationWindow
{
    OTCubeRotateView *_cubeRotateView;
    UIImageView *_cubeShadowView;
    NSMutableArray *_notificationViews;
}

@dynamic shouldAutoRotateToInterfaceOrientation;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.contentViewFrameDelegate = self;
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            UIImage *shadowImage = [UIImage imageNamed:@"ComOpenthreadOTNotificationNotifShadow.png"];
            shadowImage = [shadowImage stretchableImageWithLeftCapWidth:47 topCapHeight:47];
            _cubeShadowView = [[UIImageView alloc] initWithFrame:CGRectZero];
            _cubeShadowView.image = shadowImage;
            [self.contentView addSubview:_cubeShadowView];
        }
        
        _cubeRotateView = [[OTCubeRotateView alloc] initWithFrame:self.contentView.bounds];
        _cubeRotateView.clipsToBounds = YES;
        _cubeRotateView.backgroundColor = [UIColor blackColor];
        [self.contentView addSubview:_cubeRotateView];
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            CGRect shadowFrame = _cubeRotateView.frame;
            shadowFrame.origin.x -= 27;
            shadowFrame.origin.y -= 27;
            shadowFrame.size.width += 54;
            shadowFrame.size.height += 54;
            _cubeShadowView.frame = shadowFrame;
        }
        
        UIView *currentRotateView = [[UIView alloc] initWithFrame:CGRectZero];
        [_cubeRotateView setCurrentView:currentRotateView];
        
        _notificationViews = [NSMutableArray array];
        
        [self setHiddenPrivate:YES];
        self.state = OTNotificationWindowStateHidden;
    }
    return self;
}

//Change content view and notification view's frame when screen rotates
- (void)contentViewFrameChangedTo:(CGRect)frame
{
    _cubeRotateView.frame = self.contentView.bounds;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        CGRect shadowFrame = _cubeRotateView.frame;
        shadowFrame.origin.x -= 27;
        shadowFrame.origin.y -= 27;
        shadowFrame.size.width += 54;
        shadowFrame.size.height += 54;
        _cubeShadowView.frame = shadowFrame;
    }
    
    //Avoid status bar screenshot be stretched, hide self when cube rotating out.
    if (self.state == OTNotificationWindowStateCubeRotatingOut)
    {
        [self setHiddenPrivate:YES];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            _cubeShadowView.hidden = YES;
        }
        self.state = OTNotificationWindowStateHidden;
    }
}

//Remove notification message
- (void)removeNotificationMessage:(OTNotificationMessage *)message
{
    if ([_notificationViews containsObject:message])
    {
        [_notificationViews removeObject:message];
    }
}

//Post notification message
- (void)postNotificationMessage:(OTNotificationMessage *)message
{
    if ([_notificationViews containsObject:message])
    {
        return;
    }
    [_notificationViews addObject:message];
    [self checkStatusAfterPost];
}

- (void)removeNotificationView:(UIView *)view
{
    if([_notificationViews containsObject:view])
    {
        [_notificationViews removeObject:view];
    }
}

- (void)postNotificationView:(UIView *)view
{
    if ([_notificationViews containsObject:view])
    {
        return;
    }
    [_notificationViews addObject:view];
    [self checkStatusAfterPost];
}

- (void)checkStatusAfterPost
{
    //If self is hidden, handle notification immediately
    if (self.state == OTNotificationWindowStateHidden)
    {
        [self handleNotifications];
    }
    //If wait hiding, cancel wait hiding, and handle notification immediately
    else if (self.state ==  OTNotificationWindowStateWaitingCubeRotatingOut)
    {
        [self handleNotifications];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(cubeOut) object:nil];
    }
    // If cube rotating out, handle notification later.
    else if (self.state == OTNotificationWindowStateCubeRotatingOut)
    {
        [self performSelector:@selector(handleNotifications) withObject:nil afterDelay:1];
    }
    //otherwise, don't need to call `handleNotifications`, `handleNotifications` will call it self
}

- (void)handleNotifications
{
    //If no notification comes in, cube out.
    if (_notificationViews.count <= 0)
    {
        self.state = OTNotificationWindowStateWaitingCubeRotatingOut;
        [self performSelector:@selector(cubeOut) withObject:nil afterDelay:3];
        return;
    }
        
    //If self is hidden, cube in screenshot and set hidden to NO
    UIImage *screenshot = nil;
    if (self.state == OTNotificationWindowStateHidden)
    {
        screenshot = [self getScreenshotForCubeRect];
        [_cubeRotateView setCurrentView:[[UIImageView alloc] initWithImage:screenshot]];
        [self setHiddenPrivate:NO];
    }
    
    self.state = OTNotificationWindowStateCubeRotatingIn;
    
    //Get a notification view from notification view stack, and remove it from stack.
    id obj = _notificationViews[0];
    [_notificationViews removeObject:obj];
    
    UIView *view = nil;
    if ([obj isKindOfClass:[UIView class]])
    {
        view = obj;
    }
    else if ([obj isKindOfClass:[OTNotificationMessage class]])
    {
        view = [[OTMessageNotificationView alloc] init];
        ((OTMessageNotificationView *)view).notificationMessage = obj;
    }
    else
    {
        [self handleNotifications];
    }
    
    OTNotificationContentView *contentView = [[OTNotificationContentView alloc] initWithFrame:_cubeRotateView.bounds];
    contentView.notificationView = view;
    
    //set cube rotate view's background color to black
    _cubeRotateView.backgroundColor = [UIColor blackColor];
    
    //If on ipad, set rotating in and out content views' background image to screenshot
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        //set rotating in content view's background image to screenshot
        if (!screenshot) {screenshot = [self getScreenshotForCubeRect];}
        contentView.backgroundImage = screenshot;
        contentView.backgroundImageHidden = NO;
        
        //set rotating out content view's background image to screenshot
        UIView *currentView = _cubeRotateView.currentView;
        if ([currentView isKindOfClass:[OTNotificationContentView class]])
        {
            ((OTNotificationContentView *)currentView).backgroundImage = screenshot;
            ((OTNotificationContentView *)currentView).backgroundImageHidden = NO;
        }
    }
    
    //Show notification view.
    [_cubeRotateView rotateToView:contentView
                             from:OTCubeViewRotateSideFromUpSide
                animationDuration:0.5 completion:^{
                    //set cube rotate view's background color to clear
                    _cubeRotateView.backgroundColor = [UIColor clearColor];
                    
                    //If on ipad, set content background image to hidden
                    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                    {
                        contentView.backgroundImageHidden = YES;
                        contentView.backgroundImage = nil;
                    }
                    [self performSelector:@selector(handleNotifications) withObject:nil afterDelay:2];
                    
                    self.state = OTNotificationWindowStateShowing;
                }];
}

- (void)cubeOut
{
    self.state = OTNotificationWindowStateCubeRotatingOut;
    UIImage *screenshot = [self getScreenshotForCubeRect];
    
    //set cube rotate view's background color to black
    _cubeRotateView.backgroundColor = [UIColor blackColor];
    
    //If on ipad, set rotating out content view's background image to screenshot
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        UIView *currentView = _cubeRotateView.currentView;
        if ([currentView isKindOfClass:[OTNotificationContentView class]])
        {
            ((OTNotificationContentView *)currentView).backgroundImage = screenshot;
            ((OTNotificationContentView *)currentView).backgroundImageHidden = NO;
        }
    }
    
    [_cubeRotateView rotateToView:[[UIImageView alloc] initWithImage:screenshot]
                             from:OTCubeViewRotateSideFromUpSide
                animationDuration:0.5 completion:^{
                    [self setHiddenPrivate:YES];
                    self.state = OTNotificationWindowStateHidden;
                }];
    return;
}

- (UIImage *)getScreenshotForCubeRect
{
    CGRect screenshotRect = [_cubeRotateView.superview convertRect:_cubeRotateView.frame toView:self];
    UIImage *screenshot = [OTScreenshotHelper screenshotWithStatusBar:YES rect:screenshotRect];
    return screenshot;
}

#pragma mark - Super Methods

- (BOOL)isHidden
{
    return super.hidden;
}

- (BOOL)hidden
{
    return super.hidden;
}

- (void)setHidden:(BOOL)hidden
{
}

- (void)setHiddenPrivate:(BOOL)hidden
{
    [super setHidden:hidden];
}

- (void)show//Set hidden to NO
{
}

- (void)hide//Set hidden to YES
{
}

- (void)setWindowOrientation:(UIInterfaceOrientation)o
{
    [super setWindowOrientation:o];
}

- (void)setWindowOrientation:(UIInterfaceOrientation)o
                    animated:(BOOL)animated
{
    [super setWindowOrientation:o animated:animated];
}

- (void)setWindowOrientation:(UIInterfaceOrientation)o
                    animated:(BOOL)animated
           animationDuration:(NSTimeInterval)animationDuration
{
    [super setWindowOrientation:o animated:animated animationDuration:animationDuration];
}

#pragma mark - Singleton Method

+ (OTNotificationWindow *)sharedInstance
{
    static OTNotificationWindow *instance = nil;
    if (!instance)
    {
        instance = [[OTNotificationWindow alloc] initWithFrame:CGRectZero];
    }
    return instance;
}

@end
