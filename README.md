# WheelFlipper

Make MacBook scrolling truly natural by reversing the scroll wheel direction when "Natural Scrolling" is on.

macOS's "Natural scrolling" makes pages go up when the trackpad (or by an unintuitive, unfamiliar extensions the mouse wheel)
go up. Although that's "natural" for trackpads, it ain't so for mouses, which is annoying. WheelFlipper flips the scrolling
direction of the mouse wheel so both seem familiar on "Natural Scrolling". 

## How it works

WheelFlipper watches scroll events and flips the ones that come from a mouse wheel. Trackpad (and Magic Mouse) scrolls carry
a gesture phase; plain wheel scrolls don't, which is how the two are told apart (hopefully that's exhaustive).

## Build and install

Currently not published. Needs "manual" buildling. 

```sh
./make-cert.sh   # run once: creates a local code-signing certificate
./install.sh     # builds, copies to ~/Applications, starts at login
```

Keep **Natural scrolling** on in System Settings → Trackpad (or Mouse), then grant WheelFlipper access in System Settings → Privacy & Security → **Accessibility** when prompted.

`make-cert.sh` creates a self-signed certificate named "WheelFlipper Local Signing" in your login keychain.
This is then used to sign every build, which keeps Accessibility permission across rebuilds. Without it, builds are signed adhoc and macOS forgets the permission each time you reinstall.

To only build, without installing, run `./build.sh`. The app is written to `build/WheelFlipper.app`.

## Uninstall

```sh
./uninstall.sh
```

Then remove WheelFlipper from the Accessibility list, and optionally delete the "WheelFlipper Local Signing" certificate in Keychain Access.

## Disclaimer

This app is vibe-coded (I mean, what isn't these days?).

## License

[MIT](LICENSE)
