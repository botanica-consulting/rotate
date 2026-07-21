# Using GitHub Actions + FastLane to deploy Rotate to TestFlight

These instructions let you build **Rotate** (InsulinPumpSiteJournal) and install it via TestFlight without having access to a Mac. The process is intentionally identical to the [Loop "browser build"](https://loopkit.github.io/loopdocs/browser/bb-overview/) — if you have already built Loop this way, you already have all six Secrets and can reuse them as-is.

* You can install the app on phones using TestFlight that are not connected to your computer
* You can send builds and updates to those you care for
* You do not need to worry about specific Xcode/Mac versions for a given iOS

## Automatic Builds

The browser build **defaults to** automatically updating and building a new version of Rotate according to this schedule:

- automatically checks for updates weekly (Sunday) and if updates are found, it will build a new version of the app
- even when there are no updates, it builds on the second Sunday of the month

The [Optional](#optional) section provides instructions to modify the default behavior if desired.

> **Repeat Builders**
> - to enable automatic build, your `GH_PAT` token must have `workflow` scope
> - if you previously configured your `GH_PAT` without that scope, see [`GH_PAT` `workflow` permission](#gh_pat-workflow-permission)

## Introduction

The setup steps are somewhat involved, but nearly all are one-time steps. Subsequent builds are trivial. Your app must be updated once every 90 days (a TestFlight requirement), but the scheduled monthly build takes care of that automatically once you have built successfully one time.

If you build multiple apps with this method (e.g. Loop, Loop Follow, LoopCaregiver, Rotate), it is strongly recommended that you configure a free GitHub organization and do all your building in the organization, so you enter the 6 Secrets once at the organization level. See [LoopDocs: Create a GitHub Organization](https://loopkit.github.io/loopdocs/browser/secrets/#create-a-free-github-organization).

## Prerequisites

* A [GitHub account](https://github.com/signup). The free level comes with plenty of storage and free compute time to build the app.
* A paid [Apple Developer account](https://developer.apple.com).
* Some time. Set aside an hour or two the first time.

## Save 6 Secrets

You require 6 Secrets (alphanumeric items) to use the GitHub build method. They are **the same 6 Secrets used by every Loop-style browser build** — if you already built Loop, Loop Follow, or LoopCaregiver from a browser, reuse the values you already have and skip to [Setup the Repository](#setup-the-repository).

* Four Secrets are from your Apple Account
* Two Secrets are from your GitHub account
* Save the 6 Secrets in a text file using a plain-text editor (they are case sensitive):
    * `TEAMID`
    * `FASTLANE_ISSUER_ID`
    * `FASTLANE_KEY_ID`
    * `FASTLANE_KEY`
    * `GH_PAT`
    * `MATCH_PASSWORD`

## Generate App Store Connect API Key

This step is common for all GitHub Browser Builds; do this step only once. You will be saving 4 Secrets from your Apple Account in this step.

1. Sign in to the [Apple developer portal page](https://developer.apple.com/account/resources/certificates/list).
1. Copy the Team ID from the upper right of the screen. Record this as your `TEAMID`.
1. Go to the [App Store Connect](https://appstoreconnect.apple.com/access/integrations/api) interface, click the "Integrations" tab, and create a new key with "Admin" access. Give it the name: "FastLane API Key".
1. Record the issuer id; this will be used for `FASTLANE_ISSUER_ID`.
1. Record the key id; this will be used for `FASTLANE_KEY_ID`.
1. Download the API key itself, and open it in a text editor. The contents of this file will be used for `FASTLANE_KEY`. Copy the full text, including the "-----BEGIN PRIVATE KEY-----" and "-----END PRIVATE KEY-----" lines. Note: Apple lets you download the key file only once — if you miss it, revoke the key and create a new one.

## Create GitHub Personal Access Token

If you have previously built another app using the "browser build" method, you use the same personal access token (`GH_PAT`), so skip this step.

1. Create a [new personal access token](https://github.com/settings/tokens/new):
    * Enter a name for your token, use "FastLane Access Token".
    * Change the Expiration selection to `No expiration`.
    * Select the `workflow` permission scope — this also selects `repo` scope.
    * Click "Generate token".
    * Copy the token and record it. It will be used below as `GH_PAT`.

## Make up a Password

The first time you build with the GitHub Browser Build method for any DIY app, you make up a password and record it as `MATCH_PASSWORD`. If you already built Loop this way, use the same `MATCH_PASSWORD`. Note: if you lose `MATCH_PASSWORD`, you will need to delete and make a new Match-Secrets repository.

## GitHub Match-Secrets Repository

A private `Match-Secrets` repository is automatically created under your GitHub username the first time you run a GitHub Action. It stores your (encrypted) signing certificates and profiles, shared by all apps you build with this method. You will not take any direct actions with this repository; it just needs to exist.

## Setup the Repository

1. Fork https://github.com/0xa10/pump-rotator into your GitHub username (or organization). Do not rename the repository.
1. If you are using an organization, do the secrets step at the organization level; otherwise at the repository level:
    * Go to Settings -> Secrets and variables -> Actions and make sure the Secrets tab is open
1. For each of the following secrets, tap on "New organization secret" or "New repository secret", then add the name of the secret, along with the value you recorded for it:
    * `TEAMID`
    * `FASTLANE_ISSUER_ID`
    * `FASTLANE_KEY_ID`
    * `FASTLANE_KEY`
    * `GH_PAT`
    * `MATCH_PASSWORD`
1. Now open the Variables tab of the same page (Settings -> Secrets and variables -> Actions -> Variables).
1. Tap "New organization variable" or "New repository variable", add the name below and enter the value `true` (unlike secrets, variables are visible and can be edited):
    * `ENABLE_NUKE_CERTS`

This variable lets the build automatically revoke and recreate your Distribution certificate when it expires (once a year), so annual certificate renewal requires no action from you.

## Validate repository secrets

1. Click on the "Actions" tab of your repository and enable workflows if needed.
1. On the left side, select "1. Validate Secrets".
1. On the right side, click "Run Workflow", and tap the green `Run workflow` button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.
1. The workflow checks that the required secrets are added and correctly formatted, and creates the private `Match-Secrets` repository if it does not exist yet. If errors are detected, check the run log for details.

## Add Identifiers for the App

1. Click on the "Actions" tab of your repository.
1. On the left side, select "2. Add Identifiers".
1. On the right side, click "Run Workflow", and tap the green `Run workflow` button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.

This registers a single App ID with Apple:

| NAME | IDENTIFIER |
|-------|------------|
| Rotate | com.TEAMID.insulinpumpsitejournal |

(with `TEAMID` replaced by your team id). Rotate has no extensions, app groups, or special capabilities, so unlike Loop there is nothing to configure manually on the Apple Developer site.

## Create the App in App Store Connect

If you have created the app in App Store Connect before, you can skip this section.

1. Go to the [apps list](https://appstoreconnect.apple.com/apps) on App Store Connect and click the blue "plus" icon to create a New App.
    * Select "iOS".
    * Select a name: this will have to be unique, so you may have to try a few different names here, but it will not be the name you see on your phone, so it's not that important.
    * Select your primary language.
    * Choose the bundle ID that matches `com.TEAMID.insulinpumpsitejournal`, with TEAMID matching your team id.
    * SKU can be anything; e.g. "123".
    * Select "Full Access".
1. Click Create

You do not need to fill out the next form. That is for submitting to the app store.

## Create Building Certificates

This step is not required — the build action takes care of certificates for you (workflow "3. Create Certificates" exists and can be run manually, but the build runs it automatically).

Once a year, Apple will email you that your certificate expires in 30 days. You can ignore that email: when it expires, the next automatic or manual build will remove (nuke) the expired certificate from your Match-Secrets repository and create a new one, as long as the `ENABLE_NUKE_CERTS` variable is set to `true`.

## Build Rotate

1. Click on the "Actions" tab of your repository.
1. On the left side, select "4. Build Rotate".
1. On the right side, click "Run Workflow", and tap the green `Run workflow` button.
1. The build should take roughly 15–20 minutes; the workflow generates the Xcode project with XcodeGen, signs the app with your match certificates, and uploads the build to TestFlight.
1. Your app should eventually appear on [App Store Connect](https://appstoreconnect.apple.com/apps) under TestFlight.
1. For each phone/person you would like to install Rotate on:
    * Add them in [Users and Access](https://appstoreconnect.apple.com/access/users) on App Store Connect.
    * Add them to your TestFlight Internal Testing group.
1. Install TestFlight on the phone and accept the invitation to install Rotate.

## Automatic Build FAQs

If a GitHub repository has no activity (no commits are made) in 60 days, then GitHub disables the ability to use automated actions for that repository. You may need to manually enable your build action and manually execute it when your fork becomes stale.

## OPTIONAL

What if you don't want to allow automated updates of the repository or automatic builds?

### `GH_PAT` `workflow` permission

To enable the scheduled build and sync, the `GH_PAT` must hold the `workflow` permission scope.

1. Go to your [FastLane Access Token](https://github.com/settings/tokens)
2. It should say `repo`, `workflow` next to the `FastLane Access Token` link
3. If it does not, click on the link to open the token detail view
4. Check the `workflow` box (the `repo` scope boxes become implied)
5. Scroll down and click the green `Update token` button

If you choose not to have automatic building enabled, be sure the `GH_PAT` has at least `repo` scope or you won't be able to build manually.

### Modify scheduled building and synchronization

Two repository (or organization) variables control the weekly automation. See [How to configure a variable](#how-to-configure-a-variable).

|`SCHEDULED_SYNC`|`SCHEDULED_BUILD`|Automatic Actions|
|---|---|---|
| `true` (or unset) | `true` (or unset) | weekly update check (auto update/build), monthly build with auto update|
| `true` (or unset) | `false` | weekly update check with auto update, only builds if update detected|
| `false` | `true` (or unset) | monthly build, no auto update |
| `false` | `false` | no automatic activity|

**Warning**: if no builds happen within 90 days, your previous TestFlight build expires and a manual build is required.

### How to configure a variable

1. Go to the "Settings" tab of your repository (or organization to affect all repositories).
2. Click on `Secrets and Variables`, then `Actions`, then the `Variables` tab.
3. Click the green `New repository variable` button.
4. Type the name (`SCHEDULED_BUILD` or `SCHEDULED_SYNC`) and the value `false`, then save.

## What if I build using more than one GitHub username

This is not typical. But if you do use more than one GitHub username, follow these steps at the time of the annual certificate renewal.

1. After the certificates were removed (nuked) from username1 Match-Secrets storage, you need to switch to username2
1. Add the variable `FORCE_NUKE_CERTS=true` to the username2 repository
1. Run the action "3. Create Certificates" (or Build, but Create is faster)
1. Immediately set `FORCE_NUKE_CERTS=false` or delete the variable
