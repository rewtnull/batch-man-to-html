#!/bin/bash
#
# Batch convert manpages to html from source manpage directory to a destination directory
#
# Copyright (C) 2013 Marcus Hoffren <marcus.hoffren@gmail.com>.
# License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
# This is free software: you are free to change and redistribute it.
# There is NO WARRANTY, to the extent permitted by law.
#

error() {
    { echo -e "$@" 1>&2; }
}

[[ -f bm2h.conf ]] && . bm2h.conf || { error "bm2h.conf is missing!"; exit 1; }

scrname="bm2h"
scrver="0.5"
scrauth="Marcus Hoffren"
authnick="dMG/Up Rough"
scrcontact="marcus.hoffren@gmail.com"

usage() {
    echo "Usage: ${0##*/} [--help|-h] [--version|-v] [OPTIONS] [src] [[src] [dest]]"
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
    [[ "${BASH_VERSION}" < 4.1 ]] && { error "${scrname} requires \033[1mbash v4.1 or newer\033[m."; exit 1; }
    [[ $(type -p getopt) == "" ]] && { error "GNU getopt \033[1mrequired.\033[m"; exit 1; }
    [[ $(type -p bzcat) == "" ]] && { error "bzcat (bzip2) \033[1mrequired.\033[m"; exit 1; }
    [[ $(type -p man2html) == "" ]] && { error "man2html \033[1mrequired.\033[m"; exit 1; }
    [[ ! -d ${src_root} ]] && { error "${src_root%/} - Directory \033[1mdoes not exist\033[m."; exit 1; }
    if [[ ! -d "${dst_root}" ]]; then
	if (( ${#} == 0 )); then
	    echo -e "${dst_root%/} - Destination directory does not exist." # Strip trailing /
	    read -p "Do you want it to be created? [y/N]"
	    [[ "${REPLY}" == "y" ]] && mkdir ${dst_root%/} || exit 1
	fi
    fi
}

# Accept any. Return any
verbose_mode() {
    case ${verbose} in
	0) echo -e "${@}" 1> /dev/null;;
	1) echo -e "${@}";;
    esac
}

# Accept any. Return $src_dirs $dst_dirs
args() {
    getopt_arg=$(getopt -o "Vhsv" -l "version,help,generate-stub,verbose" -n "${0##*/}" -- "${@}") || { usage; exit 1; }
    eval set -- "${getopt_arg}"
    while (( ${#} > 0 )); do
	case "${1}" in
	    -V|--version)
				{ version; exit 0; };;
	    -h|--help)
				{ usage; exit 0; };;
	    -s|--generate-stub)
				(( ${gen_stub} == "1" )) && gen_stub="0" || gen_stub="1"
				shift;;
	    -v|--verbose)
				(( ${verbose} == "1" )) && verbose="0" || verbose="1"
				shift;;
	    --)
				shift
				break;;
	esac
    done
    case ${#} in
	0)
	    src_dirs=( $(echo "${src_root%/}${man_dirs%/}") )
	    dst_dirs=( $(echo "${dst_root%/}") );;
	1)
	    [[ ! -d ${1} ]] && { error "${1%/} - Source directory does not exist."; exit 1; }
	    src_dirs=( $(echo "${1%/}${man_dirs%/}") )
	    [[ ! -d ${src_dirs} ]] && { error "No man directories found under ${src_dirs%/}"; exit 1; }
	    dst_dirs=( $(echo "${dst_root%/}") );;
	2)
	    src_dirs=( $(echo "${1%/}${man_dirs%/}") )
	    dst_dirs=( $(echo "${2%/}") )
	    if [[ ! -d ${dst_dirs} ]]; then
		echo -e "${2%/} - Destination directory does not exist."
		read -p "Do you want it to be created? [y/N]"
		[[ "${REPLY}" == "y" ]] && mkdir ${2%/} || exit 1
	    fi;;
	*)
	    { error "${0##*/} - Wrong number of arguments."; usage; exit 1; };;
    esac
    [[ ! -d ${src_dirs} ]] && { error "${src_dirs%/} - Source directory does not exist."; exit 1; }
    [[ ! -d ${dst_dirs} ]] && { error "${dst_dirs%/} - Destination directory does not exist."; exit 1; }
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

# Accept $src_files. Return void
convert() {
	for (( i = 0; i < ${#src_files[@]}; i++ )); do
	    dst_files=$(echo "${dst_dirs}${src_files[$i]/${src_root}}") # Strip ${src_root}
	    dst_files="${dst_files/.${comp_type}/.${html_type}}" # Replace file suffix
	    if [[ ! -f "${dst_files}" ]]; then
		case ${gen_stub} in
		    0) # Skip stub manpages
			if [[ $(bzcat "${src_files[$i]}") =~ ^.so ]]; then
			    verbose_mode "Skipping stub \033[1m${src_files[$i]##*/}\033[m"
			else
			    verbose_mode "Converting ${src_files[$i]} ---> ${dst_files}"
			    bzcat "${src_files[$i]}" | man2html ${m2h_opt} > "${dst_files}" 2>/dev/null
			fi;;
		    1)
			verbose_mode "Converting ${src_files[$i]} ---> ${dst_files}"
			bzcat "${src_files[$i]}" | man2html ${m2h_opt} > "${dst_files}" 2>/dev/null;;
		esac
	    else
		 echo -e "Skipping duplicate \033[1m${src_files[$i]##*/}\033[m"
	    fi
	done
	verbose_mode ""
	verbose_mode "Done!"
	verbose_mode ""
}

sanity
args "${@}"
make_dirs "${src_dirs}" "${dst_dirs}"
files_array "${src_dirs}"
convert "${src_files}"
