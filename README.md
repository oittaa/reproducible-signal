# reproducible-signal

[![Build Status](https://travis-ci.org/oittaa/reproducible-signal.svg)](https://travis-ci.org/oittaa/reproducible-signal)

Since version 3.15.0 Signal for Android has supported reproducible builds. This is achieved by replicating the build environment as a Docker image. You'll need to build the image, run a container instance of it, compile Signal inside the container and finally compare the resulted APK to the APK that is distributed in the Google Play Store.

This script automates that.

## Ubuntu 18.04 - TL;DR

1. [Enable developer options and USB debugging](https://developer.android.com/studio/debug/dev-options#enable) on your phone.
2. Connect your phone to the computer via USB.
3. Run the commands below and follow the instructions.
```
mkdir -p "$HOME/reproducible-signal"
cd "$HOME/reproducible-signal"
wget https://raw.githubusercontent.com/oittaa/reproducible-signal/master/reproducible-signal.sh
chmod +x ./reproducible-signal.sh
./reproducible-signal.sh
```

The script might take several minutes to complete. If everything went right and the APKs match, the last line of output will be `APKs match!`

### Ubuntu 18.04 details

1. You will need around 10GB of free space for Docker images and Signal build process
2. Required packages can be installed manually `sudo apt install aapt adb docker.io wget`
3. If you had to install Docker
    1. Add yourself to the group `sudo usermod -aG docker $USER`
    2. Reboot your computer before continuing.

You can compare a previously extracted APK without connecting your phone.
```
./reproducible-signal.sh /path/to/signal.apk
```

### What if I don't have an USB cable?

Many different apps can extact installed APKs. Here's an example how to get the APK to your computer with [Files by Google](https://play.google.com/store/apps/details?id=com.google.android.apps.nbu.files) and [Google Drive](https://play.google.com/store/apps/details?id=com.google.android.apps.docs).

1. Open **Files by Google**
2. Tap `Browse`
3. Tap `Apps`
4. Under `Installed apps` scroll down to `Signal`
5. On it's right side expand the options and select `Share`
6. Tap `Save to Drive`.
7. Set `Document title` to something like `Signal.apk` and tap `Save`
8. Now you can download the APK to your computer from Google Drive

## Linux - "I want to do it manually and I know what I'm doing"

```bash
BASE_DIR="${HOME}/reproducible-signal"
APK_DIR_FROM_PLAY_STORE="${BASE_DIR}/apk-from-google-play-store"
IMAGE_BUILD_CONTEXT="${BASE_DIR}/image-build-context"
mkdir -p -- "${APK_DIR_FROM_PLAY_STORE}" "${IMAGE_BUILD_CONTEXT}"
APK_PATH=$(adb shell pm path org.thoughtcrime.securesms | grep -oP '^package:\K.*/base.apk$')
APK_FILE_FROM_PLAY_STORE="Signal-$(date '+%F_%T').apk"
adb pull \
	"${APK_PATH}" \
	"${APK_DIR_FROM_PLAY_STORE}/${APK_FILE_FROM_PLAY_STORE}"
VERSION=$(aapt dump badging "${APK_DIR_FROM_PLAY_STORE}/${APK_FILE_FROM_PLAY_STORE}" \
	| grep -oP "^package:.*versionName='\K[0-9.]+")
wget -O "${IMAGE_BUILD_CONTEXT}/Dockerfile_v${VERSION}" \
	https://raw.githubusercontent.com/signalapp/Signal-Android/v${VERSION}/Dockerfile
cd "${IMAGE_BUILD_CONTEXT}"
docker build --file Dockerfile_v${VERSION} --tag signal-android .
docker run \
	--name signal \
	--rm \
	--volume "${APK_DIR_FROM_PLAY_STORE}":/signal-build/apk-from-google-play-store \
	--workdir /signal-build \
	signal-android \
	/bin/bash -c \
		"wget https://raw.githubusercontent.com/oittaa/reproducible-signal/master/apkdiff3.py \
		&& chmod +x apkdiff3.py \
		&& git clone https://github.com/signalapp/Signal-Android.git \
		&& cd Signal-Android \
		&& git checkout --quiet v${VERSION} \
		&& ./gradlew clean assembleRelease -x signProductionPlayRelease -x signProductionWebsiteRelease \
		&& ../apkdiff3.py build/outputs/apk/play/release/Signal-play-release-unsigned-${VERSION}.apk \
			'../apk-from-google-play-store/${APK_FILE_FROM_PLAY_STORE}'"
```

## Windows / macOS / other

Probably the easiest way to use this script is to install a virtual machine with Ubuntu 18.04 on it. Then follow the instructions for Ubuntu 18.04.

At least Windows 10 with [VirtualBox](https://www.virtualbox.org/wiki/Downloads) worked flawlessly. Just remember to attach the phone to the vm!

![VirtualBox Settings](https://raw.githubusercontent.com/oittaa/reproducible-signal/master/VirtualBox-Settings-USB.png)
