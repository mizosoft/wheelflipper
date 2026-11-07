# WheelFlipper

Natural scrolling on the trackpad, normal scrolling on the mouse.

macOS has one "Natural scrolling" setting shared by the trackpad and the mouse.
WheelFlipper is a small menu bar app that reverses scrolling for mouse wheels
only, so you can keep natural scrolling on for the trackpad while the mouse
wheel scrolls the traditional way (wheel up moves the page up).

## How it works

WheelFlipper watches scroll events and flips the ones that come from a mouse
wheel. Trackpad (and Magic Mouse) scrolls carry a gesture phase; plain wheel
scrolls don't, which is how the two are told apart.

The menu bar icon shows its state:

| Icon | Meaning |
|---|---|
| Filled mouse | On: mouse wheel reversed |
| Outline mouse, dimmed | Turned off from the menu |
| Outline mouse | Paused because macOS Natural scrolling is off |
| Mouse with a slash | Accessibility permission missing |

Click it to:

- **Reverse Mouse Scrolling**: turn WheelFlipper on or off.
- **Only When Natural Scrolling Is On** (default on): pause while macOS Natural
  scrolling is off, so turning that off gives normal scrolling everywhere.
  When unchecked, the mouse is always reversed.

## Requirements

- macOS 11 or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build and install

```sh
./make-cert.sh   # once: creates a local code-signing certificate
./install.sh     # builds, copies to ~/Applications, starts at login
```

Keep **Natural scrolling** on in System Settings → Trackpad (or Mouse), then
grant WheelFlipper access in System Settings → Privacy & Security →
**Accessibility** when prompted. It starts working within a couple of seconds.

`make-cert.sh` creates a self-signed certificate named "WheelFlipper Local
Signing" in your login keychain. Signing every build with it keeps the
Accessibility permission across rebuilds. Without it, builds are signed ad
hoc and macOS forgets the permission each time you reinstall.

To only build, without installing, run `./build.sh`. The app is written to
`build/WheelFlipper.app`.

## Uninstall

```sh
./uninstall.sh
```

Then remove WheelFlipper from the Accessibility list, and optionally delete
the "WheelFlipper Local Signing" certificate in Keychain Access.

## Troubleshooting

- **The icon shows a slash after reinstalling.** The Accessibility entry no
  longer matches the app. Remove WheelFlipper from the Accessibility list
  with **–**, then run
  `launchctl kickstart -k gui/$(id -u)/io.github.mizosoft.wheelflipper` and
  grant access again.
- **Logs** are written to `/tmp/wheelflipper.log`.
- **Quit** from the menu stops it until the next login. To start it again:
  `launchctl kickstart gui/$(id -u)/io.github.mizosoft.wheelflipper`.

## License

[MIT](LICENSE)
