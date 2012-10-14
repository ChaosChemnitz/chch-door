#! /bin/sh

GPIO_OPEN=23
GPIO_CLOSE=24
GPIO_CLIP=22
SLEEP=2

for i in $GPIO_OPEN $GPIO_CLOSE $GPIO_CLIP; do
	echo "$i" > /sys/class/gpio/export
	echo "out" > /sys/class/gpio/gpio${i}/direction
done

case $1 in
	open)
		echo "1" > /sys/class/gpio/gpio${GPIO_OPEN}/value
		sleep $SLEEP
		echo "0" > /sys/class/gpio/gpio${GPIO_OPEN}/value
		;;
	close)
		echo "1" > /sys/class/gpio/gpio${GPIO_CLOSE}/value
		sleep $SLEEP
		echo "0" > /sys/class/gpio/gpio${GPIO_CLOSE}/value
		;;
	clip)
		echo "1" > /sys/class/gpio/gpio${GPIO_CLIP}/value
		sleep $SLEEP
		echo "0" > /sys/class/gpio/gpio${GPIO_CLIP}/value
		;;
	*)
		echo "valid commands are \"open\", \"close\" and \"clip\""
		;;
esac
