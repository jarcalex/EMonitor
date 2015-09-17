#!/bin/bash

export DETAIL_LINE_COUNT=5


echo "[UpTime]"
UpTime=`cat /proc/uptime`
echo "${UpTime}"


echo "<--------------------------->"

echo "[FS]"
FS=`df -T | grep -vE "tmpfs|rootfs|Filesystem|Type"  | uniq -w 15`
echo "${FS}"

echo "<--------------------------->"

echo "[getLoad]"
getLoad=`uptime | awk -F ":" '{print $NF}' | sed s/,/./g`
echo "${getLoad}"

echo "<--------------------------->"

echo "[cpuCurFreq]"
cpuCurFreq=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq`
cpuCurFreq=`expr ${cpuCurFreq} / 1000`
echo "${cpuCurFreq} MHz"

echo "<--------------------------->"

echo "[cpuMinFreq]"
cpuMinFreq=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq`
cpuMinFreq=`expr ${cpuMinFreq} / 1000`
echo "${cpuMinFreq} MHz"

echo "<--------------------------->"

echo "[cpuMaxFreq]"
cpuMaxFreq=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq`
cpuMaxFreq=`expr ${cpuMaxFreq} / 1000`
echo "${cpuMaxFreq} MHz"

echo "<--------------------------->"

echo "[cpuFreqGovernor]"
cpuFreqGovernor=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`
echo "${cpuFreqGovernor}"

echo "<--------------------------->"

echo "[TEMP]"
Heat=`vcgencmd measure_temp | sed -e s/temp=// -e s/\'C//`
echo "Temperature: ${Heat}"

echo "<--------------------------->"

echo "[cpuDetails]"
cpuDetails=`ps -e -o pcpu,user,args --sort=-pcpu | sed "/^ 0.0 /d" | head -${DETAIL_LINE_COUNT}`
echo "${cpuDetails}"

echo "<--------------------------->"

echo "[RESEAU]"
Reseau=`/sbin/ifconfig eth0 | grep RX\ bytes`
echo "${Reseau}"

echo "<--------------------------->"

echo "[CONNEXION]"
echo `netstat -nta --inet | wc -l`


echo "<--------------------------->"

echo "[IPTABLES]"
iptables=`iptables -L -n | grep DROP |wc -l`
echo "Ban_ip: ${iptables}"

echo "<--------------------------->"

echo "[RPI]"
Hostname=`hostname`
echo ${Hostname}
Firmware=`uname -v`
echo ${Firmware}
Kernel=`uname -mrs`
echo ${Kernel}
Distrib=`cat /etc/*-release | grep PRETTY_NAME=`
echo ${Distrib}
IP=`/sbin/ifconfig eth0 | grep "inet ad" | cut -d ":" -f 2 | cut -d " " -f 1`
echo ${IP}

echo "<--------------------------->"

echo "[RAM-SWAP]"
FreeMen=`free -mo`
echo "${FreeMen}"

echo "<--------------------------->"

echo "[RamDetails]"
RamProcess=`ps -e -o pmem,user,args --sort=-pmem | sed "/^ 0.0 /d" | head -${DETAIL_LINE_COUNT}`
echo "${RamProcess}"

echo "<--------------------------->"

echo "[USERS]"
Login=`last -${DETAIL_LINE_COUNT} | grep -v "wtmp" | grep "still"`
echo "${Login}"

#### Wait action ?
#read -t 2 Action

#echo ${Action}

#if [ "$Action" = "w" ]; then
#	echo "<--------------------------->"
#	echo "[SERVICES]"
#
#	ps f --pid `cat /home/pi/.pyload/pyload.pid`
#	if [ $? = 0 ]; then
#		echo "PyLoad is UP"
#	else
#		echo "PyLoad is DOWN"
#	fi
#fi
