#!/bin/bash
#
# Batch convert manpages to html from source manpage directory to a destination directory
#
# Copyright (C) 2013 Marcus Hoffren <marcus.hoffren@gmail.com>.
# License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
# This is free software: you are free to change and redistribute it.
# There is NO WARRANTY, to the extent permitted by law.
#

usage() {
    echo "Usage: ${0##*/} [-h|--help] [-v|--version] [OPTIONS <arg>] [src] [[src] [dest]]"
    echo ""
    echo "-h, --help                  Display this help and exit"
    echo "-V, --version               Display version and exit"
    echo ""
    echo "OPTIONS:"
    echo ""
    echo "-a, --automatic             Automatic mode using bm2h.conf settings"
    echo "-g, --generate-stub         Toggle generate stub html pages"
    echo "                            (Reverses bm2h.conf gen_stub setting)"
    echo "-m, --m2h-opt <\"options\">   Quoted list of man2html options"
    echo "                            See man2html(1) for more information"
    echo "                            (Overrides bm2h.conf m2h_opt setting)"
    echo "-p, --pretend               Do everything except creating directories"
    echo "                            and generating html"
    echo "                            (Reverses bm2h.conf pretend setting)"
    echo "-s, --skip                  Toggle skip/overwrite destination files"
    echo "                            (Reverses bm2h.conf skip setting)"
    echo "-t, --html-type <type>      Choose destination file suffix"
    echo "                            (Overrides bm2h.conf html_type setting)"
    echo "-v, --verbose               Toggle verbose mode"
    echo "                            (Reverses bm2h.conf verbose setting)"
    echo ""
    echo "No arguments, source directory, or source and destination directory"
    echo "accepted"
    echo ""
}

error() {
    { echo -e "${@}" 1>&2; usage; exit 1; }
}

version() {
    local scrname="Batch Man to Html"
    local scrver="0.7"
    local scrauth="Marcus Hoffren"
    local authnick="dMG/Up Rough"
    local scrcontact="marcus.hoffren@gmail.com"
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
    [[ "${BASH_VERSION}" < 4.1 ]] && error "${scrname} requires \033[1mbash v4.1 or newer\033[m." # Lexicographic comparison
    [[ -f bm2h.conf ]] && . bm2h.conf || error "${0##*/} - bm2h.conf is missing!"
    [[ $(type -p getopt) == "" ]] && error "GNU getopt \033[1mrequired.\033[m"
    [[ $(type -p bzcat) == "" ]] && error "bzcat (bzip2) \033[1mrequired.\033[m"
    [[ $(type -p man2html) == "" ]] && error "man2html \033[1mrequired.\033[m"
    [[ ! -d "${src_root}" ]] && error "${src_root%/} - Directory \033[1mdoes not exist\033[m." # Strip trailing /
    if [[ ! -d "${dst_root}" ]]; then
	if (( ${#} != 0 || ${#} != 1 )); then
	    echo -e "${dst_root%/} - Destination directory does not exist."
	    read -p "Do you want it to be created? [y/N]"
	    if [[ "${REPLY}" == "y" ]]; then
		[[ "${pretend}" != "1" ]] && mkdir ${dst_root%/}
	    else
		exit 1
	    fi
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
    getopt_arg=$(getopt -o "Vhagvpst:m:" \
			-l "version,help,generate-stub,automatic,verbose,skip,pretend,html-type:m2h-opt:" \
			-n "${0##*/}" -- "${@}") || { usage; exit 1; }
    eval set -- "${getopt_arg}"
    while (( ${#} > 0 )); do
	case "${1}" in
	    -V|--version)
				{ version; exit 0; };;
	    -h|--help)
				{ usage; exit 0; };;
	    -a|--automatic)
				automatic="1"
				shift;;
	    -g|--generate-stub)
				(( "${gen_stub}" == "1" )) && gen_stub="0" || gen_stub="1"
				shift;;
	    -m|--m2h-opt)
				[[ -n "${2}" ]] && m2h_arg="${2}"
				shift 2;; # Options with arguments need to be shifted twice
	    -p|--pretend)
				pretend="1"
				shift;;
	    -s|--skip)
				(( "${skip}" == "1" )) && skip="0" || skip="1"
				shift;;
	    -t|--html-type)
				[[ -n "${2}" ]] && html_type="${2}"
				shift 2;;
	    -v|--verbose)
				(( "${verbose}" == "1" )) && verbose="0" || verbose="1"
				shift;;
	    --)
				shift
				break;;
	esac
    done
    case ${#} in
	0)
	    case ${automatic} in
		1)
		    src_dirs=( $(echo "${src_root%/}${man_dirs%/}") )
		    dst_dirs=( $(echo "${dst_root%/}") );;
		*)
		    error "${0##*/} - Expecting either --automatic or path(s) to work with.";;
	    esac;;
	1)
	    [[ ! -d "${1}" ]] && error "${1%/} - Source directory does not exist."
	    src_dirs=( $(echo "${1%/}${man_dirs%/}") )
	    [[ ! -d "${src_dirs}" ]] && error "No man directories found under ${src_dirs%/}"
	    dst_dirs=( $(echo "${dst_root%/}") );;
	2)
	    src_dirs=( $(echo "${1%/}${man_dirs%/}") )
	    dst_dirs=( $(echo "${2%/}") )
	    if [[ ! -d "${dst_dirs}" ]]; then
		echo -e "${2%/} - Destination directory does not exist."
		read -p "Do you want it to be created? [y/N]"
		if [[ "${REPLY}" == "y" ]]; then
		    [[ "${pretend}" != "1" ]] && mkdir ${2%/}
		else
		    exit 1
		fi
	    fi;;
	*)
	    error "${0##*/} - Wrong number of arguments.";;
    esac
    [[ ! -d "${src_dirs}" ]] && error "${src_dirs%/} - Source directory does not exist."
    [[ ! -d "${dst_dirs}" ]] && error "${dst_dirs%/} - Destination directory does not exist."
}

# Accept $src_dirs, $dst_dirs. Return void
make_dirs() {
    for (( i = 0; i < ${#src_dirs[@]}; i++ )); do
	[[ ! -d "${dst_dirs}/${src_dirs[$i]##*/}" ]] && [[ "${pretend}" != "1" ]] &&
	    mkdir "${dst_dirs}/${src_dirs[$i]##*/}" # Make dirs
    done
}

# Accept $src_dirs, return $src_files
files_array() {
    for (( i = 0; i < ${#src_dirs[@]}; i++ )); do
	src_files+=( $(echo "${src_dirs[$i]}/*.${comp_type}") ) # Populate array with /path/to/filenames
    done
}

convert() {
    [[ "${pretend}" != "1" ]] && bzcat "${src_files[$i]}" | man2html ${m2h_opt} > "${dst_files}" 2>/dev/null
}

skip_stub() {
    case ${gen_stub} in
	0) # Skip stub manpages
	    if [[ $(bzcat "${src_files[$i]}") =~ ^.so ]]; then
		verbose_mode "Skipping stub \033[1m${src_files[$i]##*/}\033[m"
	    else
		verbose_mode "Converting ${src_files[$i]} ---> ${dst_files}"
		convert "${src_files}" "${dst_files}"
	    fi;;
	1)
	    verbose_mode "Converting ${src_files[$i]} ---> ${dst_files}"
	    convert "${src_files}" "${dst_files}"
    esac
}

dupe_check() {
    if [[ ! -f "${dst_files}" ]]; then
	skip_stub "${src_files}" "${dst_files}"
    else
	if (( "${skip}" == "0" )); then
	    verbose_mode "Skipping duplicate \033[1m${src_files[$i]##*/}\033[m"
	else
	    skip_stub "${src_files}" "${dst_files}"
	fi
    fi
}

# Accept $src_files. Return $dst_files
dest_files() {
	for (( i = 0; i < ${#src_files[@]}; i++ )); do
	    dst_files=$(echo "${dst_dirs}${src_files[$i]/${src_root}}") # Strip ${src_root}
	    dst_files="${dst_files/.${comp_type}/.${html_type}}" # Replace file suffix
	    dupe_check "${src_files}" "${dst_files}" # Call the rest of the functions from within the loop
	done
}

sanity
args "${@}"
make_dirs "${src_dirs}" "${dst_dirs}"
files_array "${src_dirs}"
dest_files "${src_files}"
verbose_mode ""
verbose_mode "Done!"
verbose_mode ""
