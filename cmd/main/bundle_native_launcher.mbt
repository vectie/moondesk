///|
fn native_launcher_source() -> String {
  (
    #|#import <Cocoa/Cocoa.h>
    #|#import <WebKit/WebKit.h>
    #|
    #|@interface MoondeskAppDelegate : NSObject <NSApplicationDelegate, WKNavigationDelegate>
    #|@property(nonatomic, strong) NSWindow *window;
    #|@property(nonatomic, strong) WKWebView *webView;
    #|@property(nonatomic, strong) NSTask *hostTask;
    #|@property(nonatomic, strong) NSURL *appURL;
    #|@property(nonatomic, assign) NSInteger attempts;
    #|@end
    #|
    #|@implementation MoondeskAppDelegate
    #|
    #|- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    #|  (void)notification;
    #|  [self installMenu];
    #|  [self launchHost];
    #|  [self createWindow];
    #|  [self waitForHost];
    #|}
    #|
    #|- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    #|  (void)sender;
    #|  return YES;
    #|}
    #|
    #|- (void)applicationWillTerminate:(NSNotification *)notification {
    #|  (void)notification;
    #|  [self stopHost];
    #|}
    #|
    #|- (void)installMenu {
    #|  NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];
    #|  NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    #|  [mainMenu addItem:appMenuItem];
    #|  NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Moondesk"];
    #|  NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Moondesk" action:@selector(terminate:) keyEquivalent:@"q"];
    #|  [appMenu addItem:quitItem];
    #|  [appMenuItem setSubmenu:appMenu];
    #|  [NSApp setMainMenu:mainMenu];
    #|}
    #|
    #|- (NSDictionary *)loadConfig {
    #|  NSString *path = [[NSBundle mainBundle] pathForResource:@"moondesk-config" ofType:@"json"];
    #|  if (path == nil) {
    #|    return @{};
    #|  }
    #|  NSData *data = [NSData dataWithContentsOfFile:path];
    #|  if (data == nil) {
    #|    return @{};
    #|  }
    #|  id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    #|  if ([json isKindOfClass:[NSDictionary class]]) {
    #|    return (NSDictionary *)json;
    #|  }
    #|  return @{};
    #|}
    #|
    #|- (NSString *)configString:(NSDictionary *)config key:(NSString *)key fallback:(NSString *)fallback {
    #|  id value = config[key];
    #|  if ([value isKindOfClass:[NSString class]]) {
    #|    return (NSString *)value;
    #|  }
    #|  return fallback;
    #|}
    #|
    #|- (NSInteger)configInteger:(NSDictionary *)config key:(NSString *)key fallback:(NSInteger)fallback {
    #|  id value = config[key];
    #|  if ([value respondsToSelector:@selector(integerValue)]) {
    #|    return [value integerValue];
    #|  }
    #|  return fallback;
    #|}
    #|
    #|- (void)launchHost {
    #|  NSString *hostPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"moondesk-host"];
    #|  if (hostPath == nil) {
    #|    [self showLaunchError:@"The Moondesk host executable is missing from this app bundle."];
    #|    return;
    #|  }
    #|  self.hostTask = [[NSTask alloc] init];
    #|  self.hostTask.executableURL = [NSURL fileURLWithPath:hostPath];
    #|  self.hostTask.currentDirectoryURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]];
    #|  self.hostTask.standardOutput = [NSFileHandle fileHandleWithNullDevice];
    #|  self.hostTask.standardError = [NSFileHandle fileHandleWithNullDevice];
    #|  NSError *error = nil;
    #|  if (![self.hostTask launchAndReturnError:&error]) {
    #|    NSString *message = [NSString stringWithFormat:@"Moondesk could not start its local host. %@", error.localizedDescription ?: @""];
    #|    [self showLaunchError:message];
    #|  }
    #|}
    #|
    #|- (void)createWindow {
    #|  NSDictionary *config = [self loadConfig];
    #|  NSString *host = [self configString:config key:@"host" fallback:@"127.0.0.1"];
    #|  NSInteger port = [self configInteger:config key:@"port" fallback:4199];
    #|  self.appURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%ld/", host, (long)port]];
    #|
    #|  NSRect frame = NSMakeRect(0, 0, 1280, 820);
    #|  NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    #|  self.window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];
    #|  self.window.title = @"Moondesk";
    #|  self.window.minSize = NSMakeSize(960, 640);
    #|  [self.window center];
    #|
    #|  WKWebViewConfiguration *webConfig = [[WKWebViewConfiguration alloc] init];
    #|  self.webView = [[WKWebView alloc] initWithFrame:self.window.contentView.bounds configuration:webConfig];
    #|  self.webView.navigationDelegate = self;
    #|  self.webView.allowsBackForwardNavigationGestures = YES;
    #|  self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    #|  [self.window.contentView addSubview:self.webView];
    #|
    #|  [self.window makeFirstResponder:self.webView];
    #|  [self.window makeKeyAndOrderFront:nil];
    #|  [NSApp activateIgnoringOtherApps:YES];
    #|}
    #|
    #|- (void)waitForHost {
    #|  if (self.appURL == nil) {
    #|    return;
    #|  }
    #|  self.attempts += 1;
    #|  if (self.attempts > 240) {
    #|    [self.webView loadRequest:[NSURLRequest requestWithURL:self.appURL]];
    #|    return;
    #|  }
    #|  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.appURL];
    #|  request.timeoutInterval = 0.35;
    #|  requestHTTPMethod = @"GET";
    #|  NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    #|    (void)data;
    #|    dispatch_async(dispatch_get_main_queue(), ^{
    #|      NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
    #|      if (error == nil && http != nil && http.statusCode >= 200 && http.statusCode < 500) {
    #|        [self.webView loadRequest:[NSURLRequest requestWithURL:self.appURL]];
    #|      } else {
    #|        [self performSelector:@selector(waitForHost) withObject:nil afterDelay:0.15];
    #|      }
    #|    });
    #|  }];
    #|  [task resume];
    #|}
    #|
    #|- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    #|  (void)webView;
    #|  (void)navigation;
    #|  (void)error;
    #|  [self performSelector:@selector(waitForHost) withObject:nil afterDelay:0.5];
    #|}
    #|
    #|- (void)showLaunchError:(NSString *)message {
    #|  NSAlert *alert = [[NSAlert alloc] init];
    #|  alert.messageText = @"Moondesk could not open";
    #|  alert.informativeText = message;
    #|  [alert addButtonWithTitle:@"Quit"];
    #|  [alert runModal];
    #|  [NSApp terminate:nil];
    #|}
    #|
    #|- (void)stopHost {
    #|  if (self.hostTask != nil && self.hostTask.isRunning) {
    #|    [self.hostTask terminate];
    #|  }
    #|}
    #|
    #|@end
    #|
    #|int main(int argc, const char *argv[]) {
    #|  (void)argc;
    #|  (void)argv;
    #|  @autoreleasepool {
    #|    NSApplication *app = [NSApplication sharedApplication];
    #|    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    #|    MoondeskAppDelegate *delegate = [[MoondeskAppDelegate alloc] init];
    #|    app.delegate = delegate;
    #|    [app run];
    #|  }
    #|  return 0;
    #|}
  )
}
