#!/bin/bash
set -euo pipefail

#nb: must be bash to support shopt globstar
shopt -s globstar extglob

#ANSI Escape Codes for colors to increase contrast of errors
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

st=0

# check for ripgrep
if command -v rg >/dev/null 2>&1; then
	grep=rg
	pcre2_support=1
	if [ ! rg -P '' >/dev/null 2>&1 ] ; then
		pcre2_support=0
	fi
	code_files="code/**/**.dm"
	map_files="_maps/**/**.dmm"
	code_x_515="code/**/!(__byond_version_compat).dm"
else
	pcre2_support=0
	grep=grep
	code_files="-r --include=code/**/**.dm"
	map_files="-r --include=_maps/**/**.dmm"
	code_x_515="-r --include=code/**/!(__byond_version_compat).dm"
fi

echo -e "${BLUE}Using grep provider at $(which $grep)${NC}"

if $grep -El '^\".+\" = \(.+\)' _maps/**/*.dmm;	then
    echo "${RED}ERROR: Non-TGM formatted map detected. Please convert it using Map Merger!"
    st=1
fi;
if $grep -P '^\ttag = \"icon' _maps/**/*.dmm;	then
    echo "${RED}ERROR: tag vars from icon state generation detected in maps, please remove them."
    st=1
fi;
if $grep -P 'step_[xy]' _maps/**/*.dmm;	then
    echo "${RED}ERROR: step_x/step_y variables detected in maps, please remove them."
    st=1
fi;
if $grep -P 'pixel_[^xy]' _maps/**/*.dmm;	then
    echo "${RED}ERROR: incorrect pixel offset variables detected in maps, please remove them."
    st=1
fi;
echo "Checking for cable varedits"
if $grep -P '/obj/structure/cable(/\w+)+\{' _maps/**/*.dmm;	then
    echo "${RED}ERROR: vareditted cables detected, please remove them."
    st=1
fi;
if $grep -P '\td[1-2] =' _maps/**/*.dmm;	then
    echo "${RED}ERROR: d1/d2 cable variables detected in maps, please remove them."
    st=1
fi;
echo "Checking for stacked cables"
if $grep -P '"\w+" = \(\n([^)]+\n)*/obj/structure/cable,\n([^)]+\n)*/obj/structure/cable,\n([^)]+\n)*/area/.+\)' _maps/**/*.dmm;	then
    echo "${RED}ERROR: found multiple cables on the same tile, please remove them."
    st=1
fi;
if $grep -P '^/area/.+[\{]' _maps/**/*.dmm;	then
    echo "${RED}ERROR: Vareditted /area path use detected in maps, please replace with proper paths."
    st=1
fi;
if $grep -P '\W\/turf\s*[,\){]' _maps/**/*.dmm; then
    echo "${RED}ERROR: base /turf path use detected in maps, please replace with proper paths."
    st=1
fi;
if $grep -P '^/*var/' code/**/*.dm; then
    echo "${RED}ERROR: Unmanaged global var use detected in code, please use the helpers."
    st=1
fi;
echo "Checking for space indentation"
if $grep -P '(^ {2})|(^ [^ * ])|(^    +)' code/**/*.dm; then
    echo "${RED}ERROR: space indentation detected"
    st=1
fi;
echo "Checking for mixed indentation"
if $grep -P '^\t+ [^ *]' code/**/*.dm; then
    echo "${RED}ERROR: mixed <tab><space> indentation detected"
    st=1
fi;
nl='
'
nl=$'\n'
while read f; do
    t=$(tail -c2 "$f"; printf x); r1="${nl}$"; r2="${nl}${r1}"
    if [[ ! ${t%x} =~ $r1 ]]; then
        echo "${RED}ERROR: file $f is missing a trailing newline"
        st=1
    fi;
done < <(find . -type f -name '*.dm')
if $grep -P '^/[\w/]\S+\(.*(var/|, ?var/.*).*\)' code/**/*.dm; then
    echo "${RED}ERROR: changed files contains proc argument starting with 'var'"
    st=1
fi;
if $grep -i 'centcomm' code/**/*.dm; then
    echo "${RED}ERROR: Misspelling(s) of CENTCOM detected in code, please remove the extra M(s)."
    st=1
fi;
if $grep -i 'centcomm' _maps/**/*.dmm; then
    echo "${RED}ERROR: Misspelling(s) of CENTCOM detected in maps, please remove the extra M(s)."
    st=1
fi;
if $grep -ni 'nanotransen' code/**/*.dm; then
    echo "${RED}ERROR: Misspelling(s) of nanotrasen detected in code, please remove the extra N(s)."
    st=1
fi;
if $grep -ni 'nanotransen' _maps/**/*.dmm; then
    echo "${RED}ERROR: Misspelling(s) of nanotrasen detected in maps, please remove the extra N(s)."
    st=1
fi;
if ls _maps/*.json | $grep -P "[A-Z]"; then
    echo "${RED}ERROR: Uppercase in a map json detected, these must be all lowercase."
    st=1
fi;
if $grep -i '/obj/effect/mapping_helpers/custom_icon' _maps/**/*.dmm; then
    echo "${RED}ERROR: Custom icon helper found. Please include dmis as standard assets instead for built-in maps."
    st=1
fi;
for json in _maps/*.json
do
    map_path=$(jq -r '.map_path' $json)
    while read map_file; do
        filename="_maps/$map_path/$map_file"
        if [ ! -f $filename ]
        then
            echo "${RED}ERROR: found invalid file reference to $filename in _maps/$json"
            st=1
        fi
    done < <(jq -r '[.map_file] | flatten | .[]' $json)
done
# Check for non-515 compatable .proc/ syntax
if $grep -P --exclude='__byond_version_compat.dm' '\.proc/' code/**/*.dm; then
    echo
    echo -e "${RED}ERROR: Outdated proc reference use detected in code, please use proc reference helpers.${NC}"
    st=1
fi;
exit $st
