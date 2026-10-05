# Privacy Policy

_Last updated: August 31, 2026_

**Rotate** ("the app") is designed so that your data stays yours. This policy explains what the
app does and does not do with your information.

## The short version

Rotate has no account, no server operated by us, no analytics, and no third-party tracking. The
developer never receives, sees, or stores anything you enter.

What the app itself handles *is* personal, health-related information — where on your body you
place your pump and sensor, when, and any notes you add. We are not claiming otherwise. The
point is that this data stays under your control: on your device, and — while iCloud sync is on
— in your own private iCloud. You can turn that sync off (Settings → iCloud sync) and keep
everything on this device.

## What data the app stores

Rotate stores only what you enter to keep your journal:

- The **placement sites** you record for your insulin pump and CGM sensor (e.g. "left
  abdomen"), and the **dates and times** of those placements.
- Optional **notes** you attach to a placement.
- Any **custom sites** you add for spots the body figure doesn't cover, by whatever name you
  give them.
- Your **preferences** — chosen body figure, which areas each track rotates through, the
  optional companion app for each track, and whether iCloud sync is on.

This data describes site rotation only. Rotate does **not** collect or process glucose
readings, insulin doses, or any data from your pump or CGM — it cannot read those devices.

## Where your data lives

- **On your device**, in the app's local SwiftData store.
- **In your private iCloud (CloudKit)**, while iCloud sync is on and you are signed into
  iCloud. To be plain about it: iCloud is a server, operated by Apple. The copy lives in *your*
  private CloudKit database, tied to your Apple ID, and is accessible only to you — but Apple
  does hold it. See [Apple's Privacy Policy](https://www.apple.com/legal/privacy/).
- **On this device only**, if you turn iCloud sync off in Settings → iCloud sync, or are not
  signed into iCloud.

Sync is **on by default** — it is what makes your journal reach your other devices and survive a
lost phone. When you turn it off, the app stops sending anything new to iCloud, and offers to
delete the copy already there. That deletion is a request to Apple's servers: it needs a network
connection, and it is not instant.

We — the developer — never receive, see, or store your data. There is no Botanica-operated
server involved at any point.

## What we do not do

- We do **not** collect analytics, telemetry, crash reports, or usage data.
- We do **not** use advertising or any third-party tracking SDKs.
- We do **not** sell, share, or transmit your data to anyone.
- We do **not** require or offer an account or login.

## Links to other apps

After you confirm a placement, Rotate can open another app you have installed (for example,
[Loop](https://github.com/LoopKit/Loop)) via its URL scheme. Rotate sends no data in that
hand-off — it simply brings the other app to the foreground. Any data handling in that app is
governed by that app's own privacy policy.

## Children

Rotate is a general-audience utility and does not knowingly collect data from anyone, including
children.

## Backups

If your data is included in a backup, how well it is protected depends on how *you* have backups
configured:

- **iCloud Backup** is encrypted.
- A **computer backup** (Finder or iTunes) is **not** encrypted unless you tick "Encrypt local
  backup". An unencrypted computer backup stores your journal in the clear on that computer.

See [Apple's backup documentation](https://support.apple.com/en-us/108366).

## On-device protection

The journal is stored with iOS's standard file protection for app data, and the app covers its
interface in the app switcher so your journal isn't left sitting in the snapshot iOS takes when
you switch away. Rotate has no passcode or Face ID lock of its own — your device passcode is
what protects it.

## Changes to this policy

If this policy changes, the updated version will be published in this file in the app's public
repository, with a new "Last updated" date.

## Contact

Questions about privacy? Email **privacy@botanica.consulting**.
