# Push-Up Alarm

An iOS alarm you cannot switch off by tapping a button. When it rings, the only
honest way to silence it is to do your push-ups in front of the camera. Friends in
your "circle" see whether you did them, and get a push notification the moment you
hit **Stop** instead.

## How it works

1. **Alarm** – scheduled with Apple's AlarmKit (iOS 26). It rings on the lock
   screen with the full alarm treatment (breaks through silent mode and Focus)
   and shows two buttons: **Push-ups** and **Stop**.
2. **Push-ups** opens the app straight into the camera. The alarm tone keeps
   playing inside the app until every rep is counted.
3. **Stop** is allowed (iOS requires it) but it costs you: the dismissal is posted
   to your circle immediately and the alarm rings again a few minutes later,
   up to N times (both configurable in Settings). After the last follow-up the
   day is recorded as *skipped* and your circle is told.
4. **Counting** runs fully on-device with the Vision body-pose model. A rep is
   counted only when
   - the torso (shoulder → hip) is roughly horizontal, i.e. you are in a plank filmed side-on,
   - your wrists are below your shoulders (hands on the floor),
   - the elbow angle goes from ≥ 150° to ≤ 100° and back,
   - each phase lasts at least 0.25 s (no jitter), and
   - your shoulders actually drop towards the floor, so bending your arms while
     kneeling or standing does not count.
   The rules live in `PushUpAlarm/PushUps/PushUpCounter.swift` and are unit tested.
5. **Circle** – a group of friends identified by a 6-letter invite code. Results
   are stored in the app's public CloudKit database, so there is no server to run.
   A CloudKit query subscription delivers a push notification to everyone in the
   circle for every new result. There is also a plain **Share** button on the
   result screen for people who do not want to set up CloudKit.

Video never leaves the phone; only the result ("did 10 push-ups in 0:48",
"hit Stop without doing push-ups") is shared.

## Project layout

```
PushUpAlarm.xcodeproj
PushUpAlarm/
  PushUpAlarmApp.swift          App entry, remote-notification plumbing
  AppStore.swift                State + the alarm/challenge/follow-up state machine
  Models/                       WakeAlarm, Challenge, WorkoutRecord, settings, JSON persistence
  Alarm/AlarmScheduler.swift    AlarmKit wrapper
  Alarm/AlarmIntents.swift      Intents behind the lock-screen Stop / Push-ups buttons
  PushUps/PushUpCounter.swift   Rep counting + anti-cheat rules (pure Swift)
  PushUps/PoseDetector.swift    Vision body pose → BodyPose
  PushUps/CameraManager.swift   AVCaptureSession, rotation, mirroring
  PushUps/PushUpSessionView.swift  The camera screen
  Accountability/               CloudKit circle service + store extension
  Views/                        Alarm list/editor, Circle, History, Settings
PushUpAlarmTests/               Swift Testing tests for PushUpCounter
```

## Building

Requirements: Xcode 26 or newer, a physical iPhone running iOS 26 (the simulator
has no camera), and an Apple Developer account.

1. Open `PushUpAlarm.xcodeproj`.
2. In the **PushUpAlarm** target's *Signing & Capabilities*, pick your team and
   change the bundle identifier to something you own.
3. Run on your iPhone. Grant the alarm and camera permissions when asked.

### With a free (personal-team) Apple ID

The circle feature needs the iCloud and Push Notifications capabilities, which
require a paid developer account. To build without them, clear the
`CODE_SIGN_ENTITLEMENTS` build setting (or delete
`PushUpAlarm/PushUpAlarm.entitlements`). Alarms and push-up detection work
unchanged; use the Share button on the result screen for accountability instead.

### Setting up the circle (paid account)

1. Keep the entitlements file. Xcode creates the iCloud container
   `iCloud.<your bundle id>` when you enable the capability.
2. Run the app once and create a circle. CloudKit creates the record types
   (`Circle`, `Member`, `WorkoutPost`) on first save.
3. In the [CloudKit Console](https://icloud.developer.apple.com/) → your
   container → *Schema* → *Indexes*, add a **Queryable** index on `recordName`
   for `Member` and `WorkoutPost`, and make sure `circleCode` is queryable.
   Without this, feed queries fail with "field recordName is not marked queryable".
4. When you ship, deploy the schema to Production from the same console.

### Tips for good detection

- Put the phone on the floor about 2 m to your side, propped up so the camera sees
  your whole body from the side. Landscape works best.
- Use **Practice** on the Alarms tab to check the skeleton overlay before relying on it.
- Front or back camera can be chosen in Settings.

## Status

This code was written without access to Xcode, so it has not been compiled or
run on a device yet. The AlarmKit calls follow the API as documented for iOS 26
(`AlarmManager.AlarmConfiguration`, `AlarmPresentation.Alert`, `Alarm.Schedule`)
and may need small signature adjustments against the SDK you build with.
