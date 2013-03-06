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
    echo "                            * Reverses bm2h.conf gen_stub setting"
    echo "-m, --m2h-opt <\"options\">   Quoted list of man2html options"
    echo "                            See man2html(1) for more information"
    echo "                            * Overrides bm2h.conf m2h_opt setting"
    echo "-p, --pretend               Do everything except creating directories"
    echo "                            and generating html"
    echo "-s, --skip                  Toggle skip/overwrite destination files"
    echo "                            * Reverses bm2h.conf skip setting"
    echo "-t, --html-type <type>      Choose destination file suffix"
    echo "                            * Overrides bm2h.conf html_type setting"
    echo "-v, --verbose               Toggle verbose mode"
    echo "                            * Reverses bm2h.conf verbose setting"
    echo ""
    echo "No arguments, source directory, or source and destination directory"
    echo "accepted"
    echo ""
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

# Accept any. Exit
error() {
    { echo -e "${@}" 1>&2; usage; exit 1; }
}

# Accept any. Return any
verbose_mode() {
    case ${verbose} in
	0) echo -e "${@}" 1> /dev/null;;
	1) echo -e "${@}";;
    esac
}

# Accept $1, $2. Return ${src_dirs[@]}
src_check() {
    [[ ! -d "${1}" ]] && error "${1%/} - Source directory does not exist."
    src_dirs=( $(echo "${1%/}${2%/}") )
    [[ ! -d "${src_dirs}" ]] && error "No man directories found under ${src_dirs%/}"
}

# Accept $1, $2. Return void
dst_check() {
    if [[ ! -d "${1}" ]]; then
	echo -e "${1%/} - Destination directory does not exist."
	read -p "Do you want it to be created? [y/N]"
	if [[ "${REPLY}" == "y" ]]; then
	    [[ "${pretend}" != "1" ]] && mkdir ${1%/}
	else
	    exit 1
	fi
    fi
}

# Accept any. Return ${dst_dirs[@]}
arg_check() {
    case ${#} in
	0)
	    case ${automatic} in
		1)
		    src_dirs=( $(echo "${src_root%/}${man_dirs%/}") )
		    [[ ! -d "${src_dirs}" ]] && error "${src_dirs%/} - Source directory does not exist."
		    dst_dirs=( $(echo "${dst_root%/}") )
		    dst_check "${dst_dirs}";;
		*)
		    error "${0##*/} - Expecting either --automatic or path(s) to work with.";;
	    esac;;
	1)
	    src_check "${1}" "${man_dirs}"
	    dst_dirs=( $(echo "${dst_root%/}") )
	    dst_check "${dst_dirs}";;
	2)
	    src_check "${1}" "${man_dirs}"
	    dst_dirs=( $(echo "${2%/}") )
	    dst_check "${dst_dirs}";;
	*)
	    error "${0##*/} - Wrong number of arguments.";;
    esac
}

# Accept any. Return any
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
    arg_check "${@}"
}

# Accept $1, $2. Return void
convert() {
    [[ "${pretend}" != "1" ]] && bzcat "${1}" | man2html "${m2h_opt}" > "${2}" 2>/dev/null
}

# Accept $1, $2. Return $1, $2
skip_stub() {
    case ${gen_stub} in
	0) # Skip stub manpages
	    if [[ $(bzcat "${1}") =~ ^.so ]]; then
		verbose_mode "Skipping stub \033[1m${1##*/}\033[m"
	    else
		verbose_mode "Converting ${1} ---> ${2}"
		convert "${1}" "${2}"
	    fi;;
	1)
	    verbose_mode "Converting ${1} ---> ${2}"
	    convert "${1}" "${2}"
    esac
}

# Accept $1, $2. Return $1, $2
dupe_check() {
    if [[ ! -f "${2}" ]]; then
	skip_stub "${1}" "${2}"
    else
	if (( "${skip}" == "1" )); then
	    verbose_mode "Skipping duplicate \033[1m${1##*/}\033[m"
	else
	    skip_stub "${1}" "${2}"
	fi
    fi
}

# Void
sanity() {
    [[ "${BASH_VERSION}" < 4.1 ]] && error "${0##*/} requires \033[1mbash v4.1 or newer\033[m." # Lexicographic comparison
    [[ -f bm2h.conf ]] && . bm2h.conf || error "${0##*/} - bm2h.conf is missing!"
    [[ $(type -p getopt) == "" ]] && error "GNU getopt \033[1mrequired.\033[m"
    [[ $(type -p bzcat) == "" ]] && error "bzcat (bzip2) \033[1mrequired.\033[m"
    [[ $(type -p man2html) == "" ]] && error "man2html \033[1mrequired.\033[m"
    [[ ! -d "${src_root}" ]] && error "${src_root%/} - Directory \033[1mdoes not exist\033[m." # Strip trailing /
}

# Void
make_dirs() {
    for (( i = 0; i < ${#src_dirs[@]}; i++ )); do
	[[ ! -d ${dst_dirs}/${src_dirs[$i]##*/} ]] &&
	[[ "${pretend}" != "1" ]] && mkdir "${dst_dirs}/${src_dirs[$i]##*/}" # Make dirs
    done
}

# Accept void. Return ${src_files[@]}
source_files() {
    for (( i = 0; i < ${#src_dirs[@]}; i++ )); do
	src_files+=( $(echo "${src_dirs[$i]}/*.${comp_type}") ) # Populate array with /path/to/filenames
    done
}

# Accept void. Return $dst_files
dest_files() {
	for (( i = 0; i < ${#src_files[@]}; i++ )); do
	    dst_files="${dst_dirs}${src_files[$i]/${src_root}}" # Strip ${src_root}
	    dst_files="${dst_files/.${comp_type}/.${html_type}}" # Replace file suffix
	    dupe_check "${src_files[$i]}" "${dst_files}" # Call the rest of the functions from within the loop
	done
}

sanity
args "${@}"
make_dirs
source_files
dest_files
verbose_mode ""
verbose_mode "Done!"
verbose_mode ""
