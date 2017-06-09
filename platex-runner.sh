#/bin/sh

WATCH_EVENT="attrib"

usage_exit() {
	echo "Usage: $0 [-hpbcv] monitoring-item" 1>&2
    echo
    echo "Options:" 1>&2
    echo "      h: this usage shows." 1>&2
    echo "      p: Pandoc mode." 1>&2
    echo "      b: Beamer option for Pandoc." 1>&2
    echo "      c: BibTeX citation option (for both of pLaTeX and Pandoc)." 1>&2
    echo "      v: verbose option." 1>&2
	exit 1
}

use_bibtex_or_not() {

	if [ ! -v pandoc_filter -o ! -e $1'.aux' ]
	then
		_flags="test 1"
	else
		_flags="bibtex $1"
	fi

	echo $_flags
	return
}

[ -n "$(which inotifywait 2>&1 | grep "no inotifywait in")" ] && { echo "inotify-tools is not installed." 1>&2; exit 1; }

pandoc_output_type=''
pandoc_options=''

while getopts "hpbcv" OPT
do
	case $OPT in
        p) [ -n "$(which pandoc 2>&1 | grep "no pandoc in")" ] && { echo "Pandoc is not installed." 1>&2; exit 1; }
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

[ -f "$1" ] || { echo "monitoring-item does not exist." 1>&2; usage_exit; }

file_name_with_ext=$(basename $1)
directory_path=$(dirname $1)


if [ ! -v pandoc_mode ]
then

    file_name=$(basename $file_name_with_ext .tex)

	platex_file_path=$directory_path'/'$file_name_with_ext

	trans_file_path=$directory_path'/'$file_name

	pre_commands=`use_bibtex_or_not $trans_file_path`

    inotifywait -m --event $WATCH_EVENT $directory_path'/.' | while read -r result; do echo $result | if [ -n "$(grep -G $file_name_with_ext'$')" ]; then fst_compiled_result=$(platex $platex_file_path); fst_filter_result=$(echo "$fst_compiled_result" | grep '! Emergency stop.'); [ ! -n "$fst_filter_result" ] && (display_notification=$(echo $fst_compiled_result | sed -e "s/^.*\(Output written.*\)$/\1/"); notify-send "Compilation Success" "$display_notification" --icon=dialog-information; $pre_commands && platex $platex_file_path && dvipdfmx $trans_file_path 2> /dev/null; pre_commands=`use_bibtex_or_not $trans_file_path`) || (notify-send "Compilation Failure" "Please see the error display on the terminal." --icon=dialog-error && rm $trans_file_path'.aux'; echo "$fst_compiled_result"); fi done

else

    file_ext="${file_name_with_ext##*.}"
    file_name=$(basename $file_name_with_ext '.'$file_ext)

    inotifywait -m --event $WATCH_EVENT $directory_path'/'$file_name_with_ext $ | while read -r result; do echo $result | if [ -n "$(grep -G $file_name_with_ext'$')" ]; then compiled_result=$(pandoc -s $directory_path'/'$file_name_with_ext $pandoc_output_type $pandoc_filter --latex-engine=xelatex -o $directory_path'/'$file_name'.pdf' $pandoc_options && echo "Success"); filter_result=$(echo "$compiled_result"); [ -n "$filter_result" ] && (notify-send "Compilation Sucess" "Success" --icon=dialog-information) || (notify-send "Compilation Failure" "$filter_result" --icon=dialog-error; echo "$compiled_result"); fi done

fi
