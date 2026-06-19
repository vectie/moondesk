///|
async fn run_bundle(args : Array[String]) -> Unit {
  let options = match parse_bundle_args(args) {
    Some(options) => options
    None => {
      print_usage()
      return
    }
  }
  let repo_root = @pathx.normalize(@env.current_dir().unwrap_or("."))
  let options = {
    ..options,
    workspace_root: absolute_path(options.workspace_root, repo_root),
    ui_dir: absolute_path(options.ui_dir, repo_root),
    out_dir: absolute_path(options.out_dir, repo_root),
  }
  let out_dir = options.out_dir
  let app_root = @pathx.join(out_dir, "Moondesk.app")
  let contents = @pathx.join(app_root, "Contents")
  let macos = @pathx.join(contents, "MacOS")
  let resources = @pathx.join(contents, "Resources")
  let bundled_ui = @pathx.join(resources, "ui")
  @fs.rmdir(app_root, recursive=true) catch {
    _ => ()
  }
  @fsx.make_directory(macos, recursive=true, exists_ok=true) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  @fsx.make_directory(resources, recursive=true, exists_ok=true) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  @fsx.make_directory(bundled_ui, recursive=true, exists_ok=true) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  let build_code = @process.run(
    "moon",
    ["build", "--target", "native"],
    cwd=repo_root,
  ) catch {
    error => {
      println("bundle failed: could not build native executable: \{error}")
      return
    }
  }
  if build_code != 0 {
    println(
      "bundle failed: moon build --target native exited with \{build_code}",
    )
    return
  }
  let launcher = @pathx.join(macos, "moondesk")
  let host_binary = @pathx.join(macos, "moondesk-host")
  let binary = @pathx.join(
    repo_root, "_build/native/debug/build/cmd/main/main.exe",
  )
  let binary_data = @fs.read_file(binary) catch {
    error => {
      println("bundle failed: could not read native executable: \{error}")
      return
    }
  }
  let native_window = bundle_uses_native_window(options)
  let runtime_binary = if native_window { host_binary } else { launcher }
  @fs.write_file(runtime_binary, binary_data, create=0o755, truncate=true) catch {
    error => {
      println("bundle failed: could not copy native executable: \{error}")
      return
    }
  }
  @fs.chmod(runtime_binary, 0o755) catch {
    _ => ()
  }
  if native_window {
    let launcher_source_path = @pathx.join(out_dir, "MoondeskLauncher.m")
    @fsx.write_to_file(
      launcher_source_path,
      native_launcher_source(),
      create=0o644,
    ) catch {
      error => {
        println(
          "bundle failed: could not write native launcher source: \{error}",
        )
        return
      }
    }
    let compile_code = @process.run("clang", [
      "-fobjc-arc", "-framework", "Cocoa", "-framework", "WebKit", launcher_source_path,
      "-o", launcher,
    ]) catch {
      error => {
        println("bundle failed: could not compile native launcher: \{error}")
        return
      }
    }
    if compile_code != 0 {
      println(
        "bundle failed: native launcher compile exited with \{compile_code}",
      )
      return
    }
    @fs.remove(launcher_source_path) catch {
      _ => ()
    }
    @fs.chmod(launcher, 0o755) catch {
      _ => ()
    }
  }
  let copy_code = @process.run("cp", ["-R", options.ui_dir + "/.", bundled_ui]) catch {
    error => {
      println("bundle failed: could not copy UI resources: \{error}")
      return
    }
  }
  if copy_code != 0 {
    println("bundle failed: UI resource copy exited with \{copy_code}")
    return
  }
  @fsx.write_to_file(
    @pathx.join(contents, "Info.plist"),
    info_plist(options.version, native_window),
    create=0o644,
  ) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  @fsx.write_to_file(
    @pathx.join(resources, "moondesk-config.json"),
    bundle_config_json(options).stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  @fsx.write_to_file(
    @pathx.join(resources, "README.txt"),
    "Moondesk.app contains a native MoonBit host executable, bundled Rabbita UI resources, and the \{options.shell_policy} desktop shell. It serves \{options.workspace_root} on \{options.host}:\{options.port}.\n",
    create=0o644,
  ) catch {
    error => {
      println("bundle failed: \{error}")
      return
    }
  }
  if !options.skip_sign {
    let sign_code = @process.run("codesign", [
      "--force",
      "--deep",
      "--sign",
      options.sign_identity,
      app_root,
    ]) catch {
      _ => -1
    }
    if sign_code != 0 {
      println("bundle warning: codesign failed with \{sign_code}")
    }
  }
  if options.archive {
    let archive_path = @pathx.join(out_dir, "Moondesk.app.zip")
    @fs.remove(archive_path) catch {
      _ => ()
    }
    let archive_code = @process.run("ditto", [
      "-c", "-k", "--keepParent", app_root, archive_path,
    ]) catch {
      _ => -1
    }
    if archive_code != 0 {
      println("bundle warning: archive creation failed with \{archive_code}")
    }
  }
  println("Created \{app_root}")
}

///|
fn bundle_uses_native_window(options : BundleOptions) -> Bool {
  options.shell_policy == "native-window"
}

///|
fn bundle_config_json(options : BundleOptions) -> Json {
  let native_window = bundle_uses_native_window(options)
  {
    "workspace_root": options.workspace_root,
    "ui_dir": "../Resources/ui",
    "host": options.host,
    "port": options.port,
    "open_browser": !native_window,
    "version": options.version,
    "channel": options.channel,
    "shell_policy": options.shell_policy,
    "native_window": native_window,
  }
}

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

///|
fn info_plist(version : String, native_window : Bool) -> String {
  let shell_keys = if native_window {
    (
      #|  <key>NSPrincipalClass</key>
      #|  <string>NSApplication</string>
      #|  <key>NSHighResolutionCapable</key>
      #|  <true/>
      #|  <key>NSAppTransportSecurity</key>
      #|  <dict>
      #|    <key>NSAllowsLocalNetworking</key>
      #|    <true/>
      #|  </dict>
    )
  } else {
    (
      #|  <key>LSBackgroundOnly</key>
      #|  <true/>
    )
  }
  let template =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    #|<plist version="1.0">
    #|<dict>
    #|  <key>CFBundleName</key>
    #|  <string>Moondesk</string>
    #|  <key>CFBundleDisplayName</key>
    #|  <string>Moondesk</string>
    #|  <key>CFBundleIdentifier</key>
    #|  <string>app.vectie.moondesk</string>
    #|  <key>CFBundleVersion</key>
    #|  <string>MOONDESK_VERSION</string>
    #|  <key>CFBundleShortVersionString</key>
    #|  <string>MOONDESK_VERSION</string>
    #|  <key>CFBundleExecutable</key>
    #|  <string>moondesk</string>
    #|  <key>CFBundlePackageType</key>
    #|  <string>APPL</string>
    #|MOONDESK_SHELL_KEYS
    #|  <key>LSMultipleInstancesProhibited</key>
    #|  <true/>
    #|</dict>
    #|</plist>
  template
  .replace_all(old="MOONDESK_VERSION", new=version)
  .replace_all(old="MOONDESK_SHELL_KEYS", new=shell_keys)
  .to_string()
}
