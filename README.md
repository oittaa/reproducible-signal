# reproducible-signal

[![Build Status](https://travis-ci.org/oittaa/reproducible-signal.svg)](https://travis-ci.org/oittaa/reproducible-signal)

Since version 3.15.0 Signal for Android has supported reproducible builds. This is achieved by replicating the build environment as a Docker image. You'll need to build the image, run a container instance of it, compile Signal inside the container and finally compare the resulted APK to the APK that is distributed in the Google Play Store.

This script automates that.

## Ubuntu 18.04 TL;DR

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

## Windows / macOS / other

Probably the easiest way to use this script is to install a virtual machine with Ubuntu 18.04 on it. Then follow the instructions for Ubuntu 18.04.

At least Windows 10 with [VirtualBox](https://www.virtualbox.org/wiki/Downloads) worked flawlessly. Just remember to attach the phone to the vm!

![VirtualBox Settings](https://raw.githubusercontent.com/oittaa/reproducible-signal/master/VirtualBox-Settings-USB.png)
