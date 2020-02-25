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
APK_DIR="${BASE_DIR}/apk-from-google-play-store"
IMAGE_BUILD_CONTEXT="${BASE_DIR}/image-build-context"
NEEDED_TOOLS="aapt adb docker unzip wget"

display_help() {
	printf "Usage: %s [OPTION]... [FILE]\n\n" "$0"
	printf "The script builds Signal for Android and compares it to an APK found\n"
	printf "from the connected phone. The phone must be in USB debugging mode!\n"
	printf "https://developer.android.com/studio/debug/dev-options#enable\n\n"
	printf "Alternatively you can submit an APK file as a parameter that was\n"
	printf "previously extracted, in which case you don't need a phone.\n\n"
	printf "If the script finishes successfully and the APKs match, the last \n"
	printf "line of output will be \"APKs match!\" and the exit status is set to \"0\".\n\n"
	printf "  -d, --docker-image-only build docker image, but don't compile Signal\n"
	printf "  -p, --play              compile APK with Play Store settings (default)\n"
	printf "  -w, --website           compile APK with website settings\n"
	printf "  -h, --help              display this help and exit\n"
	exit "$1"
}

display_disconnect_device() {

	if [ "${DISPLAY}" ] || [ "${WAYLAND_DISPLAY}" ] || [ "${MIR_SOCKET}" ] && command -v zenity >/dev/null 2>&1
	then
		zenity --info --timeout 60 --title="Signal APK extracted" --height 150 --width 400 \
			--text="<big>You can disconnect your phone now.</big>\n\nThis window closes automatically after 60 seconds.\n\nThe extracted APK can be found at ${APK_DIR}/${APK_FILE}" &
	else
		printf "#####################################################################\n"
		printf "#####\t\tYOU CAN DISCONNECT YOUR PHONE NOW\t\t#####\n"
		printf "#####################################################################\n"
	fi
}

print_info() {
	printf "$(date "+%F %T") %s\n" "$*"
}

error_exit() {
	printf >&2 "$(date "+%F %T") %s\n" "$*"
	exit 1
}

cleanup() {
	RV=$?
	rm -f -- "${LOGFILE}"
	exit ${RV}
}

DOCKER_ONLY=""
RELEASE="PLAY"
while true
do
	case "$1" in
		"-h" | "--help" ) display_help 0 ;;
		"-d" | "--docker-image-only" ) DOCKER_ONLY="TRUE"; shift ;;
		"-w" | "--website" ) RELEASE="WEBSITE"; shift ;;
		"-p" | "--play" ) RELEASE="PLAY"; shift ;;
		-- ) shift; break ;;
		* ) break ;;
	esac
done

# Check if we need to install packages
DOCKER_NEEDED=""
PACKAGES=""
for TOOL in ${NEEDED_TOOLS}
do
	if command -v ${TOOL} >/dev/null 2>&1
	then
		continue
	fi

	case "${TOOL}" in
		"docker")
			DOCKER_NEEDED="YES"
			[ "${PACKAGES}" ] && PACKAGES="${PACKAGES} ${TOOL}.io" || PACKAGES="${TOOL}.io"
			;;
		*)
			[ "${PACKAGES}" ] && PACKAGES="${PACKAGES} ${TOOL}" || PACKAGES="${TOOL}"
			;;
	esac
done

# Install missing packages
if [ "${PACKAGES}" ]
then
	print_info "The script requires the following packages: ${PACKAGES}"
	read -p "Would you like to install the missing dependencies? [Y/n] " RESPONSE
	case "${RESPONSE}" in
		[yY]|"") ;;
		*) error_exit "Aborting." ;;
	esac
	SUDO=""
	[ "$(id -u)" -eq 0 ] || SUDO="sudo"
	${SUDO} apt -q update
	${SUDO} apt -yq install ${PACKAGES}
	if [ "${DOCKER_NEEDED}" ] && [ "${SUDO}" ]
	then
		sudo usermod -aG docker "${USER}"
		error_exit "Reboot required."
	fi
fi

# Prepare directories and temporary files
mkdir -p -- "${APK_DIR}"
mkdir -p -- "${IMAGE_BUILD_CONTEXT}"
LOGFILE=$(mktemp --tmpdir reproducible-signal.XXXXXXXXXX.log)
trap cleanup EXIT HUP INT QUIT ABRT TERM

if [ -f "$1" ]
then
	# User submitted the APK in a file
	APK_FILE=$(basename -- "$1")
	APK_DIR=$(dirname "$(realpath -- "$1")")
elif [ -z "$1" ]
then
	COUNTER=0
	# Check if the phone is connected
	print_info "Trying to find a connected phone."
	while ! adb devices -l | grep -P '^[A-Z0-9]{5,}'
	do
		COUNTER=$((COUNTER+1))
		if [ "${COUNTER}" -ge 100 ]
		then
			error_exit "Timed out. Aborting."
		fi
		print_info "Couldn't find any connected Android devices. Waiting..."
		sleep 3
	done
	# Try to fetch the APK from the phone
	print_info "Fetching the APK from the phone."
	while ! APK_PATH=$(adb shell pm path org.thoughtcrime.securesms 2> "${LOGFILE}" | grep -oP '^package:\K.*/base.apk$')
	do
		COUNTER=$((COUNTER+1))
		if [ "${COUNTER}" -ge 100 ]
		then
			error_exit "Timed out. Aborting."
		fi
		if grep -q "^error: device unauthorized." "${LOGFILE}"
		then
			print_info "Waiting for authorization..."
		else
			error_exit "Couldn't find the Signal APK. Aborting."
		fi
		sleep 3
	done
	APK_FILE="Signal-$(date '+%F_%T').apk"
	adb pull \
		"${APK_PATH}" \
		"${APK_DIR}/${APK_FILE}"
	display_disconnect_device
else
	display_help 1
fi

print_info "Extracting version number from the APK."
VERSION=$(aapt dump badging "${APK_DIR}/${APK_FILE}" \
	| grep -oP "^package:.*versionName='\K[0-9.]+")

print_info "Building a Docker image for Signal version ${VERSION}"
print_info "This will take some time!"
wget -O "${IMAGE_BUILD_CONTEXT}/Dockerfile_v${VERSION}" \
	https://raw.githubusercontent.com/signalapp/Signal-Android/v${VERSION}/Dockerfile
cd "${IMAGE_BUILD_CONTEXT}"

### WORKAROUND FOR BROKEN DOCKER IMAGES
if grep -q '^FROM ubuntu:17.10' Dockerfile_v${VERSION}
then
	sed -i -e 's/^FROM ubuntu:17.10/FROM ubuntu:18.04/' -e '/apt-get install/ s/=\S*//g' Dockerfile_v${VERSION}
fi

docker build --file Dockerfile_v${VERSION} --tag signal-android .
[ "${DOCKER_ONLY}" ] && exit 0

print_info "Identifying ABI."
ABI=$(unzip -l "${APK_DIR}/${APK_FILE}" | grep -oP '\slib/\K[a-z0-9_\-]*' | sort -u)
if [ 1 -ne $(printf "$ABI" | wc -w) ]
then
	ABI="universal"
fi
print_info "ABI: ${ABI}"
print_info "Compiling Signal inside a container."
print_info "This will take some time!"
if [ "$RELEASE" = "PLAY" ]
then
	GRADLECMD="./gradlew clean assemblePlayRelease -x signProductionPlayRelease"
	APK_OUTPUT="app/build/outputs/apk/play/release/Signal-play-${ABI}-release-unsigned-${VERSION}.apk"
else
	GRADLECMD="./gradlew clean assembleWebsiteRelease -x signProductionWebsiteRelease"
	APK_OUTPUT="app/build/outputs/apk/website/release/Signal-website-${ABI}-release-unsigned-${VERSION}.apk"
fi
docker run \
	--name signal \
	--rm \
	--volume "${APK_DIR}":/signal-build/apks \
	--workdir /signal-build \
	signal-android \
	/bin/bash -c \
		"git clone https://github.com/signalapp/Signal-Android.git \
		&& cd Signal-Android \
		&& git checkout --quiet v${VERSION} \
		&& $GRADLECMD \
		&& sha256sum $APK_OUTPUT '../apks/${APK_FILE}' \
		&& ./apkdiff/apkdiff.py $APK_OUTPUT '../apks/${APK_FILE}'" \
			| tee "${LOGFILE}"

# Set exit status
tail -n 1 "${LOGFILE}" | grep -q "^APKs match"
