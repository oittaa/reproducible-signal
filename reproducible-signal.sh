#!/bin/sh
#
# reproducible-signal - compiles Signal and compares it to an APK
#
# Copyright (C) 2019  Eero Vuojolahti
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

set -e

BASE_DIR="${HOME}/reproducible-signal"
APK_DIR_FROM_PLAY_STORE="${BASE_DIR}/apk-from-google-play-store"
IMAGE_BUILD_CONTEXT="${BASE_DIR}/image-build-context"
NEEDED_TOOLS="aapt adb docker wget"

display_help() {
	printf >&2 "Usage: %s [signal.apk]\n\n" "$0"
	printf >&2 "\tThe script builds Signal for Android and compares it to an APK found\n"
	printf >&2 "\tfrom the connected phone. The phone must be in USB debugging mode!\n"
	printf >&2 "\thttps://developer.android.com/studio/debug/dev-options#enable\n\n"
	printf >&2 "\tAlternatively as the first parameter you can submit an APK that\n"
	printf >&2 "\twas previously extracted, in which case you don't need a phone.\n\n"
	printf >&2 "\tIf the script finishes successfully and the APKs match, the last \n"
	printf >&2 "\tline of output will be \"APKs match!\" and the exit status is set to \"0\".\n"
	exit 1
}

display_disconnect_device() {

	if [ "${DISPLAY}" ] || [ "${WAYLAND_DISPLAY}" ] || [ "${MIR_SOCKET}" ] && command -v zenity >/dev/null 2>&1
	then
		zenity --info --timeout 60 --title="Signal APK extracted" --height 150 --width 400 \
			--text="<big>You can disconnect your phone now.</big>\n\nThis window closes automatically after 60 seconds.\n\nThe extracted APK can be found at ${APK_DIR_FROM_PLAY_STORE}/${APK_FILE_FROM_PLAY_STORE}" &
	else
		printf "#####################################################################\n"
		printf "#####\t\tYOU CAN DISCONNECT YOUR PHONE NOW\t\t#####\n"
		printf "#####################################################################\n"
	fi
}

cleanup() {
  rv=$?
  rm -f -- "${LOGFILE}"
  exit ${rv}
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]
then
	display_help
fi

# Check if we need to install packages
DOCKER_NEEDED=""
PACKAGES=""
for TOOL in ${NEEDED_TOOLS}
do
	if command -v ${TOOL} >/dev/null 2>&1
	then
		continue
	fi

	# On the first iteration ask if the user wants to install the packages
	if  [ ! "${PACKAGES}" ]
	then
		printf "The script requires %s, but it's not installed.\n" "${TOOL}"
		read -p "Would you like to install the missing dependencies? [Y/n] " RESPONSE
		case "${RESPONSE}" in
			[yY]|"")
				;;
			*)
				printf >&2 "Aborting.\n"
				exit 1
				;;
		esac
	fi
	case "${TOOL}" in
		"docker")
			DOCKER_NEEDED="YES"
			[ "${PACKAGES}" ] && PACKAGES="${PACKAGES} ${TOOL}.io" || PACKAGES="${TOOL}.io"
			;;
		"aapt"|"adb"|"wget")
			[ "${PACKAGES}" ] && PACKAGES="${PACKAGES} ${TOOL}" || PACKAGES="${TOOL}"
			;;
		*)
			printf >&2 "Unknown dependency %s. Aborting.\n" "${TOOL}"
			exit 1
			;;
	esac
done

# Install missing packages
if [ "${PACKAGES}" ]
then
	SUDO=""
	[ "$(id -u)" -eq 0 ] || SUDO="sudo"
	printf "##### Installing the following packages: %s\n" "${PACKAGES}"
	${SUDO} apt -q update
	${SUDO} apt -yq install ${PACKAGES}
	if [ "${DOCKER_NEEDED}" ] && [ "${SUDO}" ]
	then
		sudo usermod -aG docker "${USER}"
		printf "##### Reboot required.\n"
		exit 1
	fi
fi

# Prepare directories
mkdir -p "${APK_DIR_FROM_PLAY_STORE}"
mkdir -p "${IMAGE_BUILD_CONTEXT}"

if [ -f "$1" ]
then
	# User submitted the APK in a file
	APK_FILE_FROM_PLAY_STORE=$(basename "$1")
	APK_DIR_FROM_PLAY_STORE=$(dirname "$(realpath "$1")")
elif [ -z "$1" ]
then
	COUNTER=0
	# Check if the phone is connected
	printf "##### Trying to find a connected phone.\n"
	while ! adb devices -l | grep -P '^[A-Z0-9]{5,}'
	do
		COUNTER=$((COUNTER+1))
		if [ "${COUNTER}" -ge 100 ]
		then
			printf >&2 "Timed out. Aborting.\n"
			exit 1
		fi
		printf "%s Coudn't find any connected Android devices. Waiting...\n" "$(date "+%F %T")"
		sleep 3
	done
	# Try to fetch the APK from the phone
	printf "##### Fetching the APK from the phone.\n"
	while ! APK_PATH=$(adb shell pm path org.thoughtcrime.securesms | grep -oP '^package:\K.*/base.apk$')
	do
		COUNTER=$((COUNTER+1))
		if [ "${COUNTER}" -ge 100 ]
		then
			printf >&2 "Timed out. Aborting.\n"
			exit 1
		fi
		printf "%s Waiting for authorization...\n" "$(date "+%F %T")"
		sleep 3
	done
	APK_FILE_FROM_PLAY_STORE="Signal-$(date '+%F_%T').apk"
	adb pull \
		"${APK_PATH}" \
		"${APK_DIR_FROM_PLAY_STORE}/${APK_FILE_FROM_PLAY_STORE}"
	display_disconnect_device
else
	display_help
fi

printf "##### Extracting version number from the APK.\n"
VERSION=$(aapt dump badging "${APK_DIR_FROM_PLAY_STORE}/${APK_FILE_FROM_PLAY_STORE}" \
	| grep -oP "^package:.*versionName='\K[0-9.]+")

printf "##### Building a Docker image for Signal.\n"
printf "##### This will take some time!\n"
wget -O "${IMAGE_BUILD_CONTEXT}/Dockerfile_v${VERSION}" \
	https://raw.githubusercontent.com/signalapp/Signal-Android/v${VERSION}/Dockerfile
cd "${IMAGE_BUILD_CONTEXT}"
docker build --file Dockerfile_v${VERSION} --tag signal-android .

printf "##### Compiling Signal inside a container.\n"
printf "##### This will take some time!\n"
LOGFILE=$(mktemp --tmpdir reproducible-signal.XXXXXXXXXX.log)
trap cleanup EXIT HUP INT QUIT ABRT TERM
docker run \
	--name signal \
	--rm \
	--volume "${APK_DIR_FROM_PLAY_STORE}":/signal-build/apk-from-google-play-store \
	--workdir /signal-build \
	signal-android \
	/bin/bash -c "wget https://raw.githubusercontent.com/oittaa/reproducible-signal/master/apkdiff3.py \
		&& chmod +x apkdiff3.py && git clone https://github.com/signalapp/Signal-Android.git \
		&& cd Signal-Android && git checkout --quiet v${VERSION} && ./gradlew clean assembleRelease \
			-x signProductionPlayRelease -x signProductionWebsiteRelease \
		; ../apkdiff3.py build/outputs/apk/play/release/Signal-play-release-unsigned-${VERSION}.apk \
			'../apk-from-google-play-store/${APK_FILE_FROM_PLAY_STORE}'" | tee "${LOGFILE}"

# Set exit status
tail -n 1 "${LOGFILE}" | grep -q "^APKs match"
