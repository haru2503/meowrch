#!/usr/bin/env fish

# Lấy giờ và phút hiện tại
set hour (date +%H | sed 's/^0*//')
set minute (date +%M | sed 's/^0*//')
set time (math "$hour * 60 + $minute")

# Hàm chọn nhiệt độ Kelvin theo thời gian
function get_kelvin
    if test $time -ge 0 -a $time -lt 180
        echo 2900
    else if test $time -ge 180 -a $time -lt 300
        echo 3200
    else if test $time -ge 300 -a $time -lt 420
        echo 3700
    else if test $time -ge 420 -a $time -lt 660
        echo 4400
    else if test $time -ge 660 -a $time -lt 840
        echo 4800
    else if test $time -ge 840 -a $time -lt 1020
        echo 4400
    else if test $time -ge 1020 -a $time -lt 1140
        echo 3700
    else if test $time -ge 1140 -a $time -lt 1260
        echo 3200
    else
        echo 3700
    end
end

# Kill process hyprsunset cũ
pkill hyprsunset
sleep 0.3

# Khởi động lại với nhiệt độ mới
set kelvin (get_kelvin)
echo "Bây giờ là $hour:$minute → Đặt nhiệt độ: $kelvin K"
hyprsunset -t $kelvin &
