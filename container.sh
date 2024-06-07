#!/bin/bash

INSTALL_PATH=/opt/elements/
PATH=${INSTALL_PATH}/oss-cad-suite/bin/:$PATH
OSS_CAD_SUITE_DATE="2024-04-16"
OSS_CAD_SUITE_STAMP="${OSS_CAD_SUITE_DATE//-}"

OPENROAD_VERSION=2024-05-15
OPENROAD_FLOW_ORGA=dnltz
OPENROAD_FLOW_VERSION=53a9b78f1f8e851c45d5e3cfa90e3bd854ca0cd7
KLAYOUT_VERSION=0.29.0
ZEPHYR_SDK_RELEASE=0.16.5
IHP_PDK_VERSION=5a42d03194e8c98558f4e34538338a60550f89b9

function fetch_oss_cad_suite_build {
	mkdir -p ${INSTALL_PATH}
	cd ${INSTALL_PATH}
	wget https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_SUITE_DATE}/oss-cad-suite-linux-x64-${OSS_CAD_SUITE_STAMP}.tgz
	tar -xvf oss-cad-suite-linux-x64-${OSS_CAD_SUITE_STAMP}.tgz
	rm oss-cad-suite-linux-x64-${OSS_CAD_SUITE_STAMP}.tgz
}

function fetch_zephyr_sdk {
	mkdir -p ${INSTALL_PATH}
	cd ${INSTALL_PATH}
	wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/zephyr-sdk-${ZEPHYR_SDK_RELEASE}_linux-x86_64.tar.xz
	wget -O - https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_RELEASE}/sha256.sum | shasum --check --ignore-missing
	tar xvf zephyr-sdk-${ZEPHYR_SDK_RELEASE}_linux-x86_64.tar.xz
	rm zephyr-sdk-${ZEPHYR_SDK_RELEASE}_linux-x86_64.tar.xz
}

function install_sg13g2 {
	mkdir -p ${INSTALL_PATH}
	cd ${INSTALL_PATH}
	mkdir -p pdks
	cd pdks/
	git clone https://github.com/IHP-GmbH/IHP-Open-PDK.git
	cd IHP-Open-PDK
	git checkout ${IHP_PDK_VERSION}
	cd ../../
}

function install_sky130 {
	mkdir -p ${INSTALL_PATH}
	cd ${INSTALL_PATH}
	mkdir -p pdks
	cd pdks/
	git clone https://github.com/RTimothyEdwards/open_pdks -b ${SKY130_VERSION}
	cd open_pdks
	./configure --enable-sky130-pdk make --prefix=${INSTALL_PATH}/../
	make -j$(nproc)
	make install
	cd ../share/pdk/
	ln -sf ${INSTALL_PATH}/sky130B/libs.tech/magic/* ${INSTALL_PATH}/../../../tools/magic/build/lib/magic/sys/
	cd ../../../
}

function install_openroad {
	mkdir -p ${INSTALL_PATH}
	cd ${INSTALL_PATH}
	sudo add-apt-repository -y ppa:deadsnakes/ppa
	sudo apt-get update
	sudo apt-get install -y python3.9 python3.9-dev python3-pip libpython3.9
	wget https://github.com/Precision-Innovations/OpenROAD/releases/download/${OPENROAD_VERSION}/openroad_2.0_amd64-ubuntu20.04-${OPENROAD_VERSION}.deb
	sudo apt install -y ./openroad_2.0_amd64-ubuntu20.04-${OPENROAD_VERSION}.deb
	wget https://www.klayout.org/downloads/Ubuntu-22/klayout_${KLAYOUT_VERSION}-1_amd64.deb
	sudo apt install -y ./klayout_${KLAYOUT_VERSION}-1_amd64.deb
	rm ./*.deb
}

function print_usage {
	echo "container.sh [-h] [sg13g2/sky130]"
	echo "\t-h: Show this help message"
	echo "\tsg13g2: Download IHP SG13G2 PDK"
	echo "\tsky130: Download SkyWater SKY130 PDK"
}

while getopts h flag
do
	case "${flag}" in
		h) print_usage
			exit 1;;
	esac
done

sg13g2=false
sky130=false
case $1 in
	sg13g2)
		sg13g2=true;;
	sky130)
		sky130=true;;
esac

if ! test -d "zephyr-sdk-${ZEPHYR_SDK_RELEASE}"; then
	fetch_zephyr_sdk
fi
if ! test -d "oss-cad-suite"; then
	fetch_oss_cad_suite_build
fi
if ! test -d "pdks"; then
	if [ "$sg13g2" = true ]; then
		install_sg13g2
	else
		echo "Skipped downloading SG13G2 PDK."
	fi

	if [ "$sky130" = true ]; then
		install_sky130
	else
		echo "Skipped downloading SKY130 PDK."
	fi
fi
if ! test -d "tools"; then
	install_openroad
fi
