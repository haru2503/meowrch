#!/usr/bin/env fish

set notify_file ~/bin/custom/zero_light/notify.sh

set brightness_file ~/bin/custom/zero_light/current_brightness.txt

if test -f $brightness_file
    set current_brightness (cat $brightness_file)
    brightnessctl s $current_brightness
    sleep 1
    $notify_file --light
    rm $brightness_file
else
    brightnessctl g > $brightness_file
    set current_brightness (cat $brightness_file)
    brightnessctl s 0
    $notify_file --dark
end