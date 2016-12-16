#/bin/sh

usage_exit() {
	echo "Usage: $0 monitoring-item" 1>&2
	exit 1
}

[ -n "$(which inotifywait 2>&1 | grep "no inotifywait in")" ] && { echo "inotify-tools is not installed."; exit 1; }

while getopts "h" OPT
do
	case $OPT in
		h) usage_exit
			;;
		\?) usage_exit
			;;
	esac
done

shift $((OPTIND - 1))

[ -f "$1" ] || { echo "monitoring-item does not exist."; usage_exit; }


file_name_with_ext=$(basename $1)
file_name=$(basename $1 .tex)
directory_path=$(dirname $1)

inotifywait -m --event modify $directory_path'/.' | while read -r result; do echo $result | if [ -n "$(grep -G $file_name_with_ext'$')" ]; then compiled_result=$(platex $file_name_with_ext && dvipdfmx $file_name); filter_result=$(echo "$compiled_result" | grep -G '^Output written'); [ -n "$filter_result" ] && notify-send "Compilation Success" "$filter_result" --icon=dialog-information || (notify-send "Compilation Failure" "Please see the error display on the terminal." --icon=dialog-error; echo "$compiled_result"); fi done
