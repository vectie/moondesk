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
