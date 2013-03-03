#!/bin/bash
#
# Batch convert manpages to html from source manpage directory to a destination directory
#
# Copyright (C) 2013 Marcus Hoffren <marcus.hoffren@gmail.com>.
# License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
# This is free software: you are free to change and redistribute it.
# There is NO WARRANTY, to the extent permitted by law.
#

source bm2h.conf

scrname="bm2h"
scrver="0.3"
scrauth="Marcus Hoffren"
authnick="dMG/Up Rough"
scrcontact="marcus.hoffren@gmail.com"

usage() {
    echo "Usage: ${0##*/} [--help|-h] [--version|-v] [OPTIONS] [source] [[source] [destination]]"
    echo ""
    echo "-h, --help            Display this help and exit"
    echo "-V, --version         Display version and exit"
    echo ""
    echo "OPTIONS:"
    echo ""
    echo "-v, --verbose         Verbose mode"
    echo "-s, --generate-stub   Generate stubs"
    echo ""
    echo "No arguments, source directory, or source and destination directory accepted."
    echo ""
}

version() {
    echo "${scrname} v${scrver}"
    echo "Copyright (C) 2013 ${scrauth} <${authnick}>."
    echo "License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>."
    echo "This is free software: you are free to change and redistribute it."
    echo "There is NO WARRANTY, to the extent permitted by law."
    echo ""
    echo "Written by ${scrauth}. <${scrcontact}>"
    echo ""
}

# Void
sanity() {
    [[ "${BASH_VERSION}" < 4.1 ]] && { echo -e "${scrname} requires \033[1mbash v4.1 or newer\033[m."; exit 1; }
    [[ $(type -p getopt) == "" ]] && { echo -e "GNU getopt \033[1mrequired.\033[m"; exit 1; }
    [[ $(type -p bzcat) == "" ]] && { echo -e "bzcat (bzip2) \033[1mrequired.\033[m"; exit 1; }
    [[ $(type -p man2html) == "" ]] && { echo -e "man2html \033[1mrequired.\033[m"; exit 1; }
    [[ ! -d ${src_root} ]] && { echo -e "${src_root} - Directory \033[1mdoes not exist\033[m."; exit 1; }
    if [[ ! -d "${dst_root}" ]]; then
	if (( ${#} == 0 )); then
	    echo "${dst_root%/} - Destination directory does not exist."
	    read -p "Do you want it to be created? [y/N]"
	    [[ "${REPLY}" == "y" ]] && mkdir ${dst_root%/} || exit 1
	fi
    fi
}

args() {
    getopt_arg=$(getopt -n "${0##*/}" -o "Vhsv" -l "version,help,generate-stub,verbose" -- "${@}") || { usage; exit 1; }
    echo "getopt_arg: $getopt_arg"
    set -- ${getopt_arg}
    echo "\$@: $@"
    while (( ${#} > 0 )); do
	case ${1} in
	    -V|--version)
				{ version; exit 0; };;
	    -h|--help)
				{ usage; exit 0; };;
	    -s|--generate-stub)
				gen_stub="1"
				echo "STUB";;
	    -v|--verbose)
				verbose="1"
				echo "VERBOSE";;
	    --)
				echo "end of getopt args"
				shift
				break;;
	    *)
				{ usage; exit 1; };;
	esac
	shift
    done
}



num_args() {
echo "1: $1 2: $2 3: $3 4: $4 5: $5"
    case ${#} in
	0)
	    echo "zero"
	    src_dirs=( $(echo "${src_root}${man_dirs}") )
	    dst_dirs=( $(echo "${dst_root}") );;
	1)
	    echo "one"
	    src_dirs=( $(echo "${1%/}${man_dirs}") ) # Strip trailing /
	    [[ ! -d ${src_dirs} ]] && { echo "No man dirs found under ${src_dirs}"; exit 1; }
	    dst_dirs=( $(echo "${dst_root}") );;
	2)
	    echo "two"
	    src_dirs=( $(echo "${1%/}${man_dirs}") )
	    dst_dirs=( $(echo "${2%/}") );;
#	    if [[ ! -d ${dst_dirs} ]]; then
#		echo "${2%/} - Destination directory does not exist."
#		read -p "Do you want it to be created? [y/N]"
#		[[ "${REPLY}" == "y" ]] && mkdir ${2%/} || exit 1
#	    fi;;
	*)
	    echo "${0##*/} - Wrong number of arguments."
	    { usage; exit 1; };;
    esac
echo "src 1: $src_dirs"
echo "dst 1: $dst_dirs"
[[ ! -d ${src_dirs} ]] && { echo "${src_dirs} - Source directory does not exist."; }
[[ ! -d ${dst_dirs} ]] && { echo "${dst_dirs} - Destination directory does not exist."; exit 1; }
}

# Accept $src_dirs, $dst_dirs. Return void
make_dirs() {
    for (( i = 0; i < ${#src_dirs[@]}; i++ )); do
	[[ ! -d ${dst_dirs}/${src_dirs[$i]##*/} ]] && mkdir "${dst_dirs}/${src_dirs[$i]##*/}" # Make dirs
    done
}

# Accept $src_dirs, return $src_files
files_array() {
    for (( i = 0; i < ${#src_dirs[@]}; i++ )); do
	src_files+=( $(echo "${src_dirs[$i]}/*.${comp_type}") ) # Populate array with /path/to/filenames
    done
}

convert() {
	for (( i = 0; i < ${#src_files[@]}; i++ )); do
	    dst_files=$(echo "${dst_dirs}${src_files[$i]/${src_root}}") # Strip ${src_root}
	    dst_files="${dst_files/.${comp_type}/.${html_type}}" # Replace file suffix
	    if [[ ! -f "${dst_files}" ]]; then
		if [[ ! $(bzcat "${src_files[$i]}") =~ ^.so ]]; then # Skip stub manpages
		    echo -e "Converting ${src_files[$i]} to ${dst_files}"
#		    bzcat "${src_files[$i]}" | man2html ${m2h_arg} > "${dst_files}"
		else
		    echo -e "Skipping stub \033[1m${src_files[$i]##*/}\033[m"
		fi
	    else
		echo -e "Skipping duplicate \033[1m${src_files[$i]##*/}\033[m"
	    fi
	done
	echo ""
	echo "Done!"
	echo ""
}

sanity
args "${@}"
num_args "${@}"



#args "${@}"
#make_dirs "${src_dirs}" "${dst_dirs}"
#files_array "${src_dirs}"
#convert "${src_files}"
