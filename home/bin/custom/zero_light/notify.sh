#!/usr/bin/env fish

if test "$argv[1]" = "--dark"
    set dark_notify_file ~/bin/custom/zero_light/dark_notify.txt
    set lines (cat $dark_notify_file)
    set line_count (count $lines)
    set idx (math (random) % $line_count + 1)

    notify-send $lines[$idx]

else if test "$argv[1]" = "--light"
    set light_notify_file ~/bin/custom/zero_light/light_notify.txt
    set lines (cat $light_notify_file)
    set line_count (count $lines)
    set idx (math (random) % $line_count + 1)

    notify-send $lines[$idx]

end