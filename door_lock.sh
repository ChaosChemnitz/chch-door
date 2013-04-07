#! /bin/sh

GPIO_OPEN=23
GPIO_CLOSE=24
GPIO_CLIP=22
GPIO_SWITCH=21
SLEEP=4
CLOSE_TIMEOUT=15

for i in $GPIO_OPEN $GPIO_CLOSE $GPIO_CLIP; do
	echo "$i" > /sys/class/gpio/export
	echo "out" > /sys/class/gpio/gpio${i}/direction
done

echo "$GPIO_SWITCH" > /sys/class/gpio/export
echo "in" > /sys/class/gpio/gpio${GPIO_SWITCH}/direction

case $1 in
	open)
		echo "1" > /sys/class/gpio/gpio${GPIO_OPEN}/value
		sleep $SLEEP
		echo "0" > /sys/class/gpio/gpio${GPIO_OPEN}/value
		;;
	close)
		TIMER=$(($CLOSE_TIMEOUT*10))
		while [ $TIMER -ge 0 ]; do
		{
			SWITCH=$(cat /sys/class/gpio/gpio${GPIO_SWITCH}/value)
			if [ $SWITCH -eq 1 ]; then
			{
				echo "1" > /sys/class/gpio/gpio${GPIO_CLOSE}/value
				sleep $SLEEP
				echo "0" > /sys/class/gpio/gpio${GPIO_CLOSE}/value
				break
			}
			fi
			sleep .1
			TIMER=$(($TIMER-1))
		}
		done
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
