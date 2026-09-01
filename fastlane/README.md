fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios register_app

```sh
[bundle exec] fastlane ios register_app
```

Register the app's bundle id with Apple (one-time)

### ios setup_app

```sh
[bundle exec] fastlane ios setup_app
```

Enable capabilities + report the App Store Connect record status (one-time)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build + upload to TestFlight (cert + sigh, no devices needed)

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Regenerate the App Store screenshots (6.9", clean 9:41 status bar)

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload App Store listing text + screenshots (no binary, no submit)

### ios release

```sh
[bundle exec] fastlane ios release
```

Upload metadata + screenshots and submit the latest build for review

### ios audit_ids

```sh
[bundle exec] fastlane ios audit_ids
```

Read-only: report enabled capabilities for both bundle ids

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
