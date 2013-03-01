#!/bin/bash
#
# Batch unpack and convert manpages to html from source manpage directory to a destination directory
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
    echo "Usage: ${0##*/} [--help|-h] [--version|-v] [source] [ [source] [destination] ]"
    echo ""
    echo "-h, --help        Display this help and exit."
    echo "-v, --version     Display version and exit."
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
    [[ $(type -p bzcat) == "" ]] && { echo -e "bzcat (bzip2) \033[1mrequired.\033[m"; exit 1; }
    [[ $(type -p man2html) == "" ]] && { echo -e "man2html \033[1mrequired.\033[m"; exit 1; }
    [[ ! -d ${src_root} ]] && { echo -e "${src_root} - Directory \033[1mdoes not exist\033[m."; exit 1; }
    [[ ! -d "${dst_root}" ]] && mkdir "${dst_root}" 2>/dev/null
}

# Accept void. Return $src_dirs, $dst_dirs
arg_null() {
    src_dirs=( $(echo "${src_root}${man_dirs}") )
    dst_dirs=( $(echo "${dst_root}") )
}

# Accept $1. Return $src_dirs, $dst_dirs
arg_one() {
    if [[ -d "${1}" ]]; then
	src_dirs=( $(echo "${1%/}${man_dirs}") ) # Strip trailing /
	if [[ ! -d ${src_dirs} ]]; then
	    echo "No man dirs found under ${src_dirs}."
	    exit 1
	fi
    else
	echo "${1%/} - Directory does not exist."
	exit 1
    fi
    dst_dirs=( $(echo "${dst_root}") )
}

# Accept $1, $2. Return $src_dirs, $dst_dirs
arg_two() {
    if [[ -d "${1}" ]]; then
	src_dirs=( $(echo "${1%/}${man_dirs}") )
	if [[ ! -d ${src_dirs} ]]; then
	    echo "No man dirs found under ${src_dirs}."
	    exit 1
	fi
	if [[ -d "${2}" ]]; then
	    dst_dirs=( $(echo "${2%/}") )
	else
	    echo "${2%/} - Destination directory does not exist."
	    read -p "Do you want it to be created? [y/N]"
	    [[ "${REPLY}" == "y" ]] && mkdir ${2%/} || exit 1
	    dst_dirs=( $(echo "${2%/}") )
	fi
    else
	echo "${1%/} - Source directory does not exist."
	exit 1
    fi

}

# Accept any. Return void
args() {
    case ${#} in
	0)
	    arg_null;;
	1)
	    case ${1} in
		--version|-v)
		    version
		    exit 0;;
		--help|-h)
		    usage
		    exit 0;;
		*)
		    arg_one "${1}"
	    esac;;
	2)
	    arg_two "${1}" "${2}";;
	*)
	    echo "Wrong number of arguments."
	    exit 1;;
    esac
}

# Accept $src_dirs, $dst_dirs. Return void
make_dirs() {
    for (( i = 0; i < ${#src_dirs[@]}; i++ )); do
	[[ ! -d ${dst_dirs}/${src_dirs[$i]##*/} ]] && $(mkdir "${dst_dirs}/${src_dirs[$i]##*/}") # Make dirs
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
		    bzcat "${src_files[$i]}" | man2html ${m2h_arg} > "${dst_files}"
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
make_dirs "${src_dirs}" "${dst_dirs}"
files_array "${src_dirs}"
convert "${src_files}"
