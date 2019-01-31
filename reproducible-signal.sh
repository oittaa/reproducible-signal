#!/bin/sh

set -e

BASE_DIR="${HOME}/reproducible-signal"
APK_DIR_FROM_PLAY_STORE="${BASE_DIR}/apk-from-google-play-store"
IMAGE_BUILD_CONTEXT="${BASE_DIR}/image-build-context"
TOOLS="aapt adb docker wget"

display_help() {
    printf >&2 "Usage: %s [signal.apk]\n\n" "$0"
    printf >&2 "\tThe script builds Signal for Android and compares it to an APK found\n"
    printf >&2 "\tfrom the connected phone. The phone must be in USB debugging mode!\n"
    printf >&2 "\thttps://developer.android.com/studio/debug/dev-options#enable\n\n"
    printf >&2 "\tAlternatively as the first parameter you can submit an APK that\n"
    printf >&2 "\twas previously extracted.\n\n"
    printf >&2 "\tIf the script finishes successfully, the last line should read:\n"
    printf >&2 "\t\"APKs match!\"\n"
    printf >&2 "\tDon't worry about the \"BUILD FAILED\" message you'll see above.\n"
    printf >&2 "\tYou don't have the signing key, but the unsigned APK was built anyway.\n"
    exit 1
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]
then
	display_help
fi

for tool in $TOOLS
do
	command -v ${tool} >/dev/null 2>&1 || { printf >&2 \
		"The script requires %s, but it's not installed. Aborting.\n" "${tool}"; exit 1; }
done

mkdir -p "${APK_DIR_FROM_PLAY_STORE}"
mkdir -p "${IMAGE_BUILD_CONTEXT}"

if [ -f "$1" ]
then
	# User submitted the apk in a file
	APK_FILE_FROM_PLAY_STORE=$(basename "$1")
	APK_DIR_FROM_PLAY_STORE=$(dirname "$(realpath "$1")")
elif [ -z "$1" ]
then
	# Try to fetch the apk from the phone
	printf "##### Fetching the APK from the phone.\n"
	APK_PATH=$(adb shell pm path org.thoughtcrime.securesms | grep -oP '^package:\K.*/base.apk$')
	APK_FILE_FROM_PLAY_STORE="Signal-$(date '+%F_%T').apk"
	adb pull \
    	"${APK_PATH}" \
    	"${APK_DIR_FROM_PLAY_STORE}/${APK_FILE_FROM_PLAY_STORE}"
else
	display_help
fi

printf "##### Extracting version number from the APK.\n"
VERSION=$(aapt dump badging "${APK_DIR_FROM_PLAY_STORE}/${APK_FILE_FROM_PLAY_STORE}" | grep -oP "^package:.*versionName='\K[0-9.]+")

printf "##### Building a Docker image for Signal.\n"
printf "##### This will take some time!\n"
wget -O "${IMAGE_BUILD_CONTEXT}/Dockerfile_v${VERSION}" \
	https://raw.githubusercontent.com/signalapp/Signal-Android/v${VERSION}/Dockerfile
cd "${IMAGE_BUILD_CONTEXT}"
docker build --file Dockerfile_v${VERSION} --tag signal-android .

printf "##### Compiling Signal inside a container.\n"
printf "##### This will take some time!\n"
docker run \
	--name signal \
	--rm \
	--volume "${APK_DIR_FROM_PLAY_STORE}":/signal-build/apk-from-google-play-store \
	--workdir /signal-build \
	signal-android \
	/bin/bash -c "wget https://raw.githubusercontent.com/oittaa/reproducible-signal/master/apkdiff3.py && chmod +x apkdiff3.py && git clone https://github.com/signalapp/Signal-Android.git && cd Signal-Android && git checkout --quiet v${VERSION} && ./gradlew clean assembleRelease; ../apkdiff3.py build/outputs/apk/play/release/Signal-play-release-unsigned-${VERSION}.apk '../apk-from-google-play-store/${APK_FILE_FROM_PLAY_STORE}'"
