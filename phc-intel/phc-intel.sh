#!/bin/bash -e
shopt -s nullglob

if [ "$1" = set ]; then
	. /etc/phc-intel.conf
	[ -n "$VIDS" ] || exit
	for i in $(< /proc/cmdline); do
		[ $i = nophc ] && exit
	done
	for i in /sys/devices/system/cpu/cpu*/cpufreq/phc_vids; do
		echo $VIDS > "$i"
	done
	exit
fi

case "$1" in
start)
	. /etc/phc-intel.conf
	if [ -z "$VIDS" ]; then
		echo '=> Please edit /etc/phc-intel.conf'
		exit 1
	fi
	echo ':: Setting PHC VIDs'
	for i in /sys/devices/system/cpu/cpu*/cpufreq/phc_vids; do
		echo $VIDS > "$i"
	done
	;;
stop)
	echo ':: Resetting default PHC VIDs'
	for i in /sys/devices/system/cpu/cpu*/cpufreq; do
		[ -e "$i/phc_default_vids" -a -e "$i/phc_vids" ] && cp "$i"/phc_{default_,}vids
	done
	;;
status)
	check_off () {
		for i in /sys/devices/system/cpu/cpu*/cpufreq; do
			[ "$(< $i/phc_vids)" = "$(< $i/phc_default_vids)" ] || return;
		done
	}
	check_on () {
		for i in /sys/devices/system/cpu/cpu*/cpufreq/phc_vids; do
			[[ "$(< $i)" =~ "$VIDS" ]] || return;
		done
	}
	echo -n 'PHC status: '
	. /etc/phc-intel.conf
	if check_off; then
		echo 'STOPPED'
	elif check_on; then
		echo 'STARTED'
	else
		echo 'UNKNOWN'
	fi
	;;
setup)
	echo ':: Removing old phc-intel modules'
	echo
	for i in /usr/lib/modules/*; do
		if [ -f "$i/phc-intel.ko" -a ! -f "$i/version" ]; then
			rm -f "$i/phc-intel.ko"
			rmdir --ignore-fail-on-non-empty "$i"
		elif [ -f "$i/extra/phc-intel.ko" -a ! -d "$i/kernel" ]; then
			rm -f "$i/extra/phc-intel.ko"
			rmdir -p --ignore-fail-on-non-empty "$i/extra"
		fi
	done
	echo ':: Compiling new phc-intel module'
	echo
	cd /usr/src/phc-intel/
	make
	echo
	echo ':: Installing new phc-intel module'
	echo
	make install
	echo
	echo ':: Cleaning up'
	echo
	make clean
	;;
*)
	echo "usage: $0 {start|stop|status|setup|set}"
esac