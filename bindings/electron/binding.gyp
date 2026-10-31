{
  "targets": [{
    "target_name": "permission_guide",
    "conditions": [["OS=='mac'", {
      "sources": ["src/addon.mm"],
      "include_dirs": ["<!@(node -p \"require('node-addon-api').include_dir\")", "../../Sources/CPermissionGuide/include"],
      "defines": ["NAPI_VERSION=8", "NAPI_DISABLE_CPP_EXCEPTIONS"],
      "xcode_settings": {
        "GCC_ENABLE_CPP_EXCEPTIONS": "NO",
        "CLANG_CXX_LANGUAGE_STANDARD": "c++17",
        "MACOSX_DEPLOYMENT_TARGET": "13.0",
        "OTHER_LDFLAGS": [
          "-L<(module_root_dir)/native/lib/<(target_arch)",
          "-lCPermissionGuide", "-lPermissionGuide",
          "-L/usr/lib/swift",
          "<!(node scripts/toolchain-lib.cjs)",
          "-Wl,-rpath,/usr/lib/swift",
          "-framework AppKit", "-framework CoreGraphics", "-framework ApplicationServices",
          "-framework Foundation", "-framework QuartzCore"
        ]
      }
    }, {
      "type": "none"
    }]]
  }]
}
