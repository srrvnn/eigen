#import "ARTopMenuInternalMobileWebViewController.h"

#define MAX_AGE 3600 // 1 hour


@interface ARTopMenuInternalMobileWebViewController () <ARTopMenuRootViewController>
@property (nonatomic, assign) BOOL hasSuccessfullyLoadedLastRequest;
@property (nonatomic, strong) NSDate *lastRequestLoadedAt;
@end


@implementation ARTopMenuInternalMobileWebViewController

- (void)reload;
{
    if (self.isViewLoaded) {
        [self loadURL:self.currentURL];
    }
}

// If the currently visible view is the root webview, reload it. This ensures that an existing view hierachy isn't
// thrown out every time the user changes tabs, but that the user also has a way to effectively ‘reload’ a webview.
// This is needed because there could have been a connectivity/server error at the time of loading and also because
// content needs to be refreshable.
//
- (BOOL)shouldBeReloaded;
{
    return !self.hasSuccessfullyLoadedLastRequest || (self.isCurrentlyVisibleViewController && self.isContentStale);
}

- (BOOL)isCurrentlyVisibleViewController;
{
    return self.navigationController.visibleViewController == self && [[ARTopMenuViewController sharedController] rootNavigationController] == self.navigationController;
}

- (BOOL)isContentStale;
{
    return self.lastRequestLoadedAt.timeIntervalSinceNow < -MAX_AGE;
}

#pragma mark - ARTopMenuRootViewController

// Currently the only VC that does anything with remote notifications is the ‘bell’ tab, so this generelization is good
// enough for now, but might need changing once other tabs start having notifications as well.
- (void)remoteNotificationsReceived:(NSUInteger)notificationCount;
{
    [self reload];
}

- (void)markRemoteNotificationsAsRead;
{
    if (self.lastRequestLoadedAt != nil && self.hasSuccessfullyLoadedLastRequest && self.isCurrentlyVisibleViewController) {
        ARTopTabControllerIndex index = [[ARTopMenuViewController sharedController] indexOfRootViewController:self];
        [[ARTopMenuViewController sharedController] setNotificationCount:0 forControllerAtIndex:index];
    }
}

#pragma mark - Overrides

- (instancetype)initWithURL:(NSURL *)url;
{
    if ((self = [super initWithURL:url])) {
        _hasSuccessfullyLoadedLastRequest = YES;
    }
    return self;
}

- (void)loadURL:(NSURL *)url
{
    self.lastRequestLoadedAt = nil;
    [super loadURL:url];
}

- (void)viewWillAppear:(BOOL)animated;
{
    [super viewWillAppear:animated];
    if ([self shouldBeReloaded]) [self reload];
}

- (void)viewDidAppear:(BOOL)animated;
{
    [super viewDidAppear:animated];
    [self markRemoteNotificationsAsRead];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView;
{
    [super webViewDidFinishLoad:webView];

    NSCachedURLResponse *urlResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:webView.request];
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)urlResponse.response;
    NSInteger statusCode = httpResponse.statusCode;
    self.hasSuccessfullyLoadedLastRequest = statusCode >= 200 && statusCode < 300;

    if (self.hasSuccessfullyLoadedLastRequest) {
        self.lastRequestLoadedAt = [NSDate date];
    }

    [self markRemoteNotificationsAsRead];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error;
{
    [super webView:webView didFailLoadWithError:error];

    // This happens when we cancel loading the request and route internally from ARInternalMobileWebViewController.
    if (error.code != NSURLErrorCancelled) {
        self.hasSuccessfullyLoadedLastRequest = NO;
    }
}

@end
