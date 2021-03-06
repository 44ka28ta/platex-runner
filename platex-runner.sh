#/bin/sh

WATCH_EVENT="attrib"

usage_exit() {
    echo "Usage: $0 [-hpbcv] monitoring-item" 1>&2
    echo
    echo "Options:" 1>&2
    echo "      h: this usage shows." 1>&2
    echo "      p: Pandoc mode." 1>&2
    echo "      u: upLaTeX mode." 1>&2
    echo "      b: Beamer option for Pandoc." 1>&2
    echo "      n: Pandoc option for Numbered section." 1>&2
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

prepare_pandoc_env() {

	if [ -n "$(which pandoc 2>&1 | grep "no pandoc in")" ]
	then
	       
		echo "Pandoc is not installed." 1>&2
		echo "try to use cabal package manager." 1>&2

		if [ -n "$(which cabal 2>&1 | grep "no cabal in")" ]
		then
			exit 1
		fi

		if [ -n "$(ls *.cabal 2>&1 | grep "No such file")" ]
		then
			echo "create cabal profile." 1>&2

			cat << EOS > auto-gen.cabal
name: automatic-generated-profile
version: 0.0.1
build-type: Simple
cabal-version: >=1.10

library
  build-depends:       pandoc
                      ,pandoc-citeproc
  default-language:    Haskell2010
EOS
		fi

		cabal new-build

		cabal_state='cabal new-exec'
		cabal_delimiter=' --'

		echo "finished cabal preparation." 1>&2

	fi
}

[ -n "$(which inotifywait 2>&1 | grep "no inotifywait in")" ] && { echo "inotify-tools is not installed." 1>&2; exit 1; }

pandoc_output_type=''
pandoc_options=''

cabal_state=''
cabal_delimiter=''

while getopts "hpubcnv" OPT
do
	case $OPT in
        p) prepare_pandoc_env
            pandoc_mode=1
            ;;
	u) uplatex_mode=1
            ;;
        b) pandoc_output_type='-t beamer'
            ;;
        c) pandoc_filter='--filter pandoc-citeproc'
            ;;
        v) pandoc_options=$pandoc_options' --verbose'
            ;;
		n) pandoc_options=$pandoc_options' -N'
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

    if [ ! -v uplatex_mode ]
    then
        
        inotifywait -m --event $WATCH_EVENT $directory_path'/.' | while read -r result; do echo $result | if [ -n "$(grep -G $file_name_with_ext'$')" ]; then fst_compiled_result=$(platex $platex_file_path); fst_filter_result=$(echo "$fst_compiled_result" | grep '! Emergency stop.'); [ ! -n "$fst_filter_result" ] && (display_notification=$(echo $fst_compiled_result | sed -e "s/^.*\(Output written.*\)$/\1/"); notify-send "Compilation Success" "$display_notification" --icon=dialog-information; $pre_commands && platex $platex_file_path && dvipdfmx $trans_file_path 2> /dev/null; pre_commands=`use_bibtex_or_not $trans_file_path`) || (notify-send "Compilation Failure" "Please see the error display on the terminal." --icon=dialog-error && rm $trans_file_path'.aux'; echo "$fst_compiled_result"); fi done
    else
        inotifywait -m --event $WATCH_EVENT $directory_path'/.' | while read -r result; do echo $result | if [ -n "$(grep -G $file_name_with_ext'$')" ]; then fst_compiled_result=$(uplatex $platex_file_path); fst_filter_result=$(echo "$fst_compiled_result" | grep '! Emergency stop.'); [ ! -n "$fst_filter_result" ] && (display_notification=$(echo $fst_compiled_result | sed -e "s/^.*\(Output written.*\)$/\1/"); notify-send "Compilation Success" "$display_notification" --icon=dialog-information; $pre_commands && uplatex $platex_file_path && dvipdfmx $trans_file_path 2> /dev/null; pre_commands=`use_bibtex_or_not $trans_file_path`) || (notify-send "Compilation Failure" "Please see the error display on the terminal." --icon=dialog-error && rm $trans_file_path'.aux'; echo "$fst_compiled_result"); fi done

    fi

else
    file_ext="${file_name_with_ext##*.}"
    file_name=$(basename $file_name_with_ext '.'$file_ext)

    inotifywait -m --event $WATCH_EVENT $directory_path'/.' | while read -r result; do echo $result | if [ -n "$(grep -G $file_name_with_ext'$')" ]; then compiled_result=$($cabal_state pandoc$cabal_delimiter -s $directory_path'/'$file_name_with_ext $pandoc_output_type $pandoc_filter --pdf-engine=xelatex -o $directory_path'/'$file_name'.pdf' $pandoc_options && echo "Success"); filter_result=$(echo "$compiled_result"); [ -n "$filter_result" ] && (notify-send "Compilation Sucess" "Success" --icon=dialog-information) || (notify-send "Compilation Failure" "$filter_result" --icon=dialog-error; echo "$compiled_result"); fi done

fi
