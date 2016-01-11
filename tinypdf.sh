#!/bin/bash

#
# Utils
#

red=$(tput setaf 1)
bold=$(tput bold)
reset=$(tput sgr0)
green=$(tput setaf 76)
purple=$(tput setaf 171)
tan=$(tput setaf 3)

e_header() { printf "\n${bold}${purple}==========  %s  ==========${reset}\n" "$@" 
}
e_success() { printf "${green}✔ %s${reset}\n" "$@"
}
e_error() { printf "${red}✖ %s${reset}\n" "$@"
}
e_warning() { printf "${tan}➜ %s${reset}\n" "$@"
}
e_bold() { printf "${bold}%s${reset}\n" "$@"
}
e_arrow() { printf "➜ $@\n"
}

type_exists() {
  if [ $(type -P $1) ]; then
    return 0
  fi
  return 1
}

seek_confirmation() {
  printf "\n${bold}$@${reset}"
  read -p " (y/n) " -n 1 </dev/tty
  printf "\n"
}

# Test whether the result of an 'ask' is a confirmation
is_confirmed() {
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    return 0
  fi
    return 1
}

#
# Processing arguments
#

show_help() {
  printf "Usage: $(basename "$0") (-d DIRECTORY | -f FILE) [-q QUALITY] [-i] [-h]\n"
  printf "    -d DIRECTORY base directory\n"
  printf "    -f FILE      filename\n"
  printf "    -q QUALITY   dpi resolution\n"
  printf "    -i           interactive mode (preview compressed files)\n"
  printf "    -h           help\n"
}

validate_dpi() {
  if ! [ "$1" -eq "$1" ] 2>/dev/null; then
    e_error "Please provide the quality as a number (in DPI)"
  fi
}

# compress_file INPUT OUTPUT DPI
compress_file() {
	gs                                       \
	  -q -dNOPAUSE -dBATCH -dSAFER           \
	  -sDEVICE=pdfwrite                      \
	  -dCompatibilityLevel=1.3               \
	  -dPDFSETTINGS=/screen                  \
	  -dEmbedAllFonts=true                   \
	  -dSubsetFonts=true                     \
	  -dAutoRotatePages=/None                \
	  -dColorImageDownsampleType=/Bicubic    \
	  -dColorImageResolution="$3"            \
	  -dGrayImageDownsampleType=/Bicubic     \
	  -dGrayImageResolution="$3"             \
	  -dMonoImageDownsampleType=/Bicubic     \
	  -dMonoImageResolution="$3"             \
	  -sOutputFile="$2"                      \
	  "$1"
}

COMPRESSED_SUFFIX=".tinypdf_compressed.pdf"

# compress_with_options INPUT DPI
compress_with_options() {
    INPUT=$1
    DPI=$2
    INTERACTIVE_MODE=$3
    OUTPUT="$INPUT$COMPRESSED_SUFFIX"
    BASENAME="$(basename "$INPUT")"
    e_arrow "Shrinking $BASENAME"
    compress_file "$INPUT" "$OUTPUT" $DPI
    # Check file sizes
    ISIZE="$(echo $(wc -c "$INPUT") | cut -f1 -d\ )"
    OSIZE="$(echo $(wc -c "$OUTPUT") | cut -f1 -d\ )"
    if [ "$ISIZE" -lt "$OSIZE" ]; then
      e_warning "Input file smaller than the compressed file, keeping the original version"
      echo
      rm "$OUTPUT"
    else
        if $INTERACTIVE_MODE; then
          qlmanage -p "$OUTPUT" &>/dev/null &
          ql_pid=$!
          seek_confirmation "Are you happy with the compressed version?"
          kill $ql_pid
          if is_confirmed; then
            e_success "Replacing original file with compressed version"
            mv "$OUTPUT" "$INPUT"
          else
            e_warning "Keeping the original version"
            rm "$OUTPUT"
          fi
        else 
            mv "$OUTPUT" "$INPUT"
        fi
        echo
    fi
}

# Checking that Ghostscript is installed
if ! type_exists 'gs'; then
  e_error "Ghostscript missing: please install ghostscript or set it in your path. Aborting."
  exit 1
fi

# Checking that gnumfmt and gdu are installed
if ! ( (type_exists 'gdu') && ( type_exists 'gnumfmt') ); then
  e_error "CoreUtils missing: please install coreutils or set it in your path. Aborting."
  exit 1
fi

if [[ $# -eq 0 ]] ; then
    show_help
    exit 1
fi

DPI=125
COMPULSORY_PARAM=false
INTERACTIVE=false

OPTIND=1
while getopts "d:f:q:ih" opt; do
  case "$opt" in
    d) DIRECTORY="$OPTARG"
       COMPULSORY_PARAM=true
       FILEPATH=$DIRECTORY
      ;;
    f) FILE="$OPTARG"
       COMPULSORY_PARAM=true
       FILEPATH=$FILE
      ;;
    q) DPI=$OPTARG
       validate_dpi $DPI
      ;;
    h) show_help
      exit 1
      ;;
    i) INTERACTIVE=true
      ;;
    \?) e_error "Invalid option: -$OPTARG" >&2
      show_help
      exit 1
      ;;
    :) e_error "Option -$OPTARG requires an argument" >&2
      show_help
      exit 1
      ;;
  esac
done
shift "$((OPTIND-1))"

if ! $COMPULSORY_PARAM; then
    e_error "You must specify a file or a directory"
    show_help
    exit 1
fi

#
# Main
#

e_header TinyPDF
echo

ORIGINAL_SIZE=$(gdu -s -b $FILEPATH 2> /dev/null | cut -f1)
FILENUMBER=0

if [ -z "$DIRECTORY" ]; then
  if [ ! -f "$FILE" ]; then
    e_error "File $FILE doesn't exist"
    exit 1
  fi
  e_bold "Shrinking PDF file $FILE with quality $DPI DPI"
  compress_with_options "$FILE" $DPI $INTERACTIVE
  ((FILENUMBER++))
else
  if [ ! -d "$DIRECTORY" ]; then
    e_error "Directory $DIRECTORY doesn't exist"
    exit 1
  fi
  e_bold "Shrinking PDF files in $DIRECTORY with quality $DPI DPI"
  while read f; 
  do
    ((FILENUMBER++))
    compress_with_options "$f" $DPI $INTERACTIVE
  done < <( find $DIRECTORY -iname "*.pdf" )
  e_bold "Cleaning up temporary files"
  find "$DIRECTORY" -type f -name "*$COMPRESSED_SUFFIX" -exec rm {} +
fi

# TODO: Use a counter for filenumber
NEW_SIZE=$(gdu -s -b $FILEPATH | cut -f1)
DIFF_SIZE=$((ORIGINAL_SIZE - NEW_SIZE))
DIFF_SIZE_HUMAN=$(gnumfmt --to=iec --suffix=B $DIFF_SIZE)

echo
e_success "Processed $FILENUMBER file(s) ($DIFF_SIZE_HUMAN saved)"
