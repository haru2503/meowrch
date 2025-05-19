#!/usr/bin/env fish

# Lấy giờ và phút hiện tại
set hour (date +%H | sed 's/^0*//')
set minute (date +%M | sed 's/^0*//')

# Tính tổng phút trong ngày
set time (math "$hour * 60 + $minute")

# Hàm đổi Kelvin
function set_kelvin
    echo "Bây giờ là $hour:$minute"
    echo "Đang đổi nhiệt độ..."
    echo "Đổi nhiệt độ thành $argv[1]K"
    hyprsunset -t $argv[1]
end

# Logic đổi Kelvin theo thời gian
if test $time -ge 0 -a $time -lt 180
    set_kelvin 2700       # 0h–3h
else if test $time -ge 181 -a $time -lt 300
    set_kelvin 3000       # 3h–5h
else if test $time -ge 301 -a $time -lt 420
    set_kelvin 3500       # 5h–7h
else if test $time -ge 421 -a $time -lt 660
    set_kelvin 4000       # 7h–11h
else if test $time -ge 661 -a $time -lt 840
    set_kelvin 4800       # 11h–14h
else if test $time -ge 841 -a $time -lt 1020
    set_kelvin 4000       # 14h–17h
else if test $time -ge 1021 -a $time -lt 1140
    set_kelvin 3500       # 17h–19h
else if test $time -ge 1141 -a $time -lt 1260
    set_kelvin 3000       # 19h–21h
else if test $time -ge 1261 -o $time -lt 1439
    set_kelvin 3500       # 21h–0h
else
    set_kelvin 4000       # fallback
end
