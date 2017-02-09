#/bin/sh

usage_exit() {
	echo "Usage: $0 [-hpbcv] monitoring-item" 1>&2
    echo
    echo "Options:" 1>&2
    echo "      h: this usage shows." 1>&2
    echo "      p: pandoc mode." 1>&2
    echo "      b: beamer option for pandoc." 1>&2
    echo "      c: bibtex citation option for pandoc." 1>&2
    echo "      v: verbose option." 1>&2
	exit 1
}

[ -n "$(which inotifywait 2>&1 | grep "no inotifywait in")" ] && { echo "inotify-tools is not installed."; exit 1; }

pandoc_output_type=''
pandoc_filter=''
pandoc_options=''

while getopts "hpbcv" OPT
do
	case $OPT in
        p) [ -n "$(which pandoc 2>&1 | grep "no pandoc in")" ] && { echo "pandoc is not installed."; exit 1; }
            pandoc_mode=1
            ;;
        b) pandoc_output_type='-t beamer'
            ;;
        c) pandoc_filter='--filter pandoc-citeproc'
            ;;
        v) pandoc_options='--verbose'
            ;;
		h) usage_exit
			;;
		\?) usage_exit
			;;
	esac
done

shift $((OPTIND - 1))

[ -f "$1" ] || { echo "monitoring-item does not exist."; usage_exit; }

file_name_with_ext=$(basename $1)
directory_path=$(dirname $1)


if [ ! -v pandoc_mode ]
then

    file_name=$(basename $file_name_with_ext .tex)

    inotifywait -m --event modify $directory_path'/.' | while read -r result; do echo $result | if [ -n "$(grep -G $file_name_with_ext'$')" ]; then compiled_result=$(platex $directory_path'/'$file_name_with_ext && dvipdfmx $directory_path'/'$file_name); filter_result=$(echo "$compiled_result" | grep -G '^Output written'); [ -n "$filter_result" ] && notify-send "Compilation Success" "$filter_result" --icon=dialog-information || (notify-send "Compilation Failure" "Please see the error display on the terminal." --icon=dialog-error; echo "$compiled_result"); fi done

else

    file_name=$(basename $file_name_with_ext .markdown)

    inotifywait -m --event modify $directory_path'/.' | while read -r result; do echo $result | if [ -n "$(grep -G $file_name_with_ext'$')" ]; then compiled_result=$(pandoc -s $directory_path'/'$file_name_with_ext $pandoc_output_type $pandoc_filter --latex-engine=xelatex -o $directory_path'/'$file_name'.pdf' $pandoc_options && echo "Success"); filter_result=$(echo "$compiled_result"); [ -n "$filter_result" ] && (notify-send "Compilation Sucess" "Success" --icon=dialog-information) || (notify-send "Compilation Failure" "$filter_result" --icon=dialog-error; echo "$compiled_result"); fi done

fi
