#!/bin/bash

export OUTDIR=/tmp/out_rhode_kernel
export MODDIR=/tmp/out_rhode_modules

mymake() {
	if [ ! -d ${OUTDIR} ]; then
		mkdir ${OUTDIR}
	fi
	make LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-suse-linux- CROSS_COMPILE_ARM32=arm-suse-linux-gnueabi- O=${OUTDIR} "$@"
}

setenv () {
	export ARCH=arm64
	export SUBARCH=arm64
	export PATH=/mnt/ssd/20/prebuilts/clang/host/linux-x86/clang-r475365b/bin/:/mnt/nvme/rhode/out_20/host/linux-x86/bin/:$PATH
}

checkenv () {
	if [[ $ARCH != "arm64" ]] || [[ $SUBARCH != "arm64" ]]; then
		echo "Environment variables are unset!"
		return 1
	fi
	echo "All good!"
}

fullclean () {
	setenv
	if ! checkenv; then
		echo "Aborting!"
		return 1
	fi
	echo "Performing a full clean..."
	mymake mrproper
}

clean () {
	setenv
	if ! checkenv; then
		echo "Aborting!"
		return 1
	fi
	echo "Cleaning..."
	mymake clean
}

mkcfg () {
	setenv
	if ! checkenv; then
		echo "Aborting!"
		return 1
	fi
	if [ -f ".config" ]; then
		echo ".config exists, running make oldconfig"
		mymake oldconfig
	else
		echo ".config not found"
		mymake lineageos_rhode_defconfig
	fi
}

editcfg () {
	setenv
	if ! checkenv; then
		echo "Aborting!"
		return 1
	fi
	if [ -f "${OUTDIR}/.config" ]; then
		echo ".config exists"
		mymake nconfig
	else
		echo ".config not found, run mkcfg first!"
		return 1
	fi
}

savecfg () {
	setenv
	if ! checkenv; then
		echo "Aborting!"
		return 1
	fi
	mymake savedefconfig
	mv ${OUTDIR}/defconfig arch/arm64/configs/lineageos_rhode_defconfig
}

build () {
	setenv
	if ! checkenv; then
		echo "Aborting!"
		return 1
	fi
	if [ -z "$1" ]; then
		echo "No number of jobs has been passed"
		return 1
	fi
	echo "Running make..."
	mkdir ${MODDIR}
	mymake -j${1}
	mymake INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=${MODDIR} modules_install
}

mkzip () {
	AKDIR=/mnt/data/android/rhode/AnyKernel3-master/
	AKMODDIR=${AKDIR}/modules/vendor/lib/modules/
	cp ${OUTDIR}/arch/arm64/boot/Image ${AKDIR}
	/mnt/nvme/rhode/out_20/host/linux-x86/bin/mkdtboimg.py create ${AKDIR}/dtbo.img --page_size=4096 $(find ${OUTDIR}/arch/arm64/boot/dts -type f -name "*.dtbo" | sort)
	cat $(find ${OUTDIR}/arch/arm64/boot/dts -type f -name "*.dtb" | sort) > ${AKDIR}/dtb.img
	find ${MODDIR} -type f -name "*.ko" -exec cp {} ${AKMODDIR} \;
	for i in $(cat /mnt/ssd/20/device/motorola/sm6225-common/BoardConfigCommon.mk | grep .ko | cut -f1 -d '\'); do
		mv ${AKMODDIR}/$(printf ${i} | cut -f1 -d ':') ${AKMODDIR}/$(printf ${i} | cut -f2 -d ':');
	done
	(cd ${AKDIR} && zip -r ../kernels/kernel_Tom_`date +%Y%m%d`.zip *)
	printf "Sideload zip? [Y/n]"
	read answer
	if [[ $answer != "n" ]]; then
		adb sideload /mnt/data/android/rhode/kernels/kernel_Tom_`date +%Y%m%d`.zip
	fi
}
