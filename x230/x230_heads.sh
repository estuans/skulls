#!/bin/bash
# SPDX-License-Identifier: GPL-3.0+
# Copyright (C) 2018, Martin Kepplinger <martink@posteo.de>

set -e

cd "$(dirname "$0")"

source "util/functions.sh"

have_input_image=0

usage()
{
	echo "Skulls for the X230"
	echo "  Run this script on the X230 directly."
	echo ""
	echo "  This flashes Heads to your BIOS, see http://osresearch.net"
	echo "  Heads is a different project. No image is included."
	echo "  Read https://github.com/osresearch/heads for how to build it"
	echo "  Make sure you booted Linux with iomem=relaxed"
	echo ""
	echo "Usage: $0 -i <heads_image>.rom"
}

args=$(getopt -o i:h -- "$@")
if [ $? -ne 0 ] ; then
	usage
	exit 1
fi

eval set -- "$args"
while [ $# -gt 0 ]
do
	case "$1" in
	-i)
		INPUT_IMAGE_PATH=$2
		have_input_image=1
		shift
		;;
	-h)
		usage
		exit 1
		;;
	--)
		shift
		break
		;;
	*)
		echo "Invalid option: $1"
		exit 1
		;;
	esac
	shift
done

force_x230_and_root

if [ ! "$have_input_image" -gt 0 ] ; then
	image_available=$(ls -1 | grep rom || true)
	if [ -z "${image_available}" ] ; then
		echo "No image file found. Please add -i <file>"
		echo ""
		usage
		exit 1
	fi

	prompt="file not specified. Please select a file to flash:"
	options=( $(find -maxdepth 1 -name "*rom" -print0 | xargs -0) )

	PS3="$prompt "
	select INPUT_IMAGE_PATH in "${options[@]}" "Quit" ; do
		if (( REPLY == 1 + ${#options[@]} )) ; then
			exit

		elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
			break

		else
			echo "Invalid option. Try another one."
		fi
	done
fi


OUTPUT_PATH=output
INPUT_IMAGE_NAME=$(basename "${INPUT_IMAGE_PATH}")
OUTPUT_IMAGE_NAME=${INPUT_IMAGE_NAME%%.*}_prepared.rom
OUTPUT_IMAGE_PATH=${OUTPUT_PATH}/${OUTPUT_IMAGE_NAME}

echo -e "input: ${INPUT_IMAGE_NAME}"
echo -e "output: ${OUTPUT_IMAGE_PATH}"

input_filesize=$(wc -c <"$INPUT_IMAGE_PATH")
reference_filesize=12582912
if [ ! "$input_filesize" -eq "$reference_filesize" ] ; then
	echo "Error: input file must be 12MB of size"
	exit 1
fi

rm -rf ${OUTPUT_PATH}
mkdir ${OUTPUT_PATH}

cp "${INPUT_IMAGE_PATH}" "${OUTPUT_IMAGE_PATH}"
LAYOUT_FILENAME="x230-layout-heads.txt"

echo "0x00000000:0x00000fff ifd" > ${OUTPUT_PATH}/${LAYOUT_FILENAME}
echo "0x00001000:0x00002fff gbe" >> ${OUTPUT_PATH}/${LAYOUT_FILENAME}
echo "0x00003000:0x004fffff me" >> ${OUTPUT_PATH}/${LAYOUT_FILENAME}
echo "0x00500000:0x00bfffff bios" >> ${OUTPUT_PATH}/${LAYOUT_FILENAME}

echo -e "${YELLOW}WARNING${NC}: Make sure not to power off your computer or interrupt this process in any way!"
echo -e "         Interrupting this process may result in irreparable damage to your computer!"
check_battery
while true; do
	read -r -p "Flash the BIOS now? y/N: " yn
	case $yn in
		[Yy]* ) cd ${OUTPUT_PATH} && flashrom -p internal --layout ${LAYOUT_FILENAME} --image bios -w "${OUTPUT_IMAGE_NAME}"; break;;
		[Nn]* ) exit;;
		* ) exit;;
	esac
done

rm -rf ${OUTPUT_PATH}

while true; do
	read -r -p "Reboot now? (please do!) Y/n: " yn
	case $yn in
		[Yy]* ) reboot ;;
		[Nn]* ) exit;;
		* ) reboot;;
	esac
done
