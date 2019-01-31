# reproducible-signal

[![Build Status](https://travis-ci.org/oittaa/reproducible-signal.svg)](https://travis-ci.org/oittaa/reproducible-signal)

Since version 3.15.0 Signal for Android has supported reproducible builds. This is achieved by replicating the build environment as a Docker image. You'll need to build the image, run a container instance of it, compile Signal inside the container and finally compare the resulted APK to the APK that is distributed in the Google Play Store.

## TL;DR

1. [Enable developer options and USB debugging from your phone](https://developer.android.com/studio/debug/dev-options#enable)
2. Connect your phone to the computer via USB
3. run `./reproducible-signal.sh`
