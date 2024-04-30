APP_DIR="/Applications/kitty.app/Contents/MacOS"

cd /Users/ronaldrecord
${APP_DIR}/kitty --title 'Command Line Cowboy' \
                 --override allow_remote_control=yes \
                 --listen-on unix:/tmp/cowboykitty > /dev/null 2>&1 &
