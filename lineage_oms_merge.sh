#!/bin/bash
#
# Copyright (C) 2017 Nathan Chancellor
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>


###########
#         #
#  USAGE  #
#         #
###########

# PURPOSE: Merge Substratum support from LineageOMS org into LineageOS repos
#
# USAGE: $ bash lineage_oms_merge.sh
#
# IMPORTANT: IF YOU HAVE FORKED LINEAGE REPOS, YOU ONLY NEED TO RUN THIS ONCE
#            OTHERWISE, RUN THIS ONCE PER REPO SYNC


###############
#             #
#  VARIABLES  #
#             #
###############

# THIS VARIABLE MUST BE SET BEFORE CONTINUING
SOURCE_DIR=

if [[ -z ${SOURCE_DIR} ]]; then
    echo "Please open the script and set the SOURCE_DIR variable on line 36!"
    exit
fi

# DO NOT EDIT THIS
SUBS_REPOS="
.repo/manifests
frameworks/base
frameworks/native
packages/apps/Contacts
packages/apps/ContactsCommon
packages/apps/Dialer
packages/apps/ExactCalculator
packages/apps/PackageInstaller
packages/apps/PhoneCommon
packages/apps/Settings
system/core
system/sepolicy
vendor/cm"

unset RESULT_STRING

############
#          #
#  COLORS  #
#          #
############

GREEN="\033[01;32m"
RED="\033[01;31m"
RESTORE="\033[0m"


###############
#             #
#  FUNCTIONS  #
#             #
###############

# PRINTS A FORMATTED HEADER TO POINT OUT WHAT IS BEING DONE TO THE USER
function echoText() {
    echo -e ${RED}
    echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
    echo -e "==  ${1}  =="
    echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
    echo -e ${RESTORE}
}

# CREATES A NEW LINE IN TERMINAL
function newLine() {
    echo -e ""
}

# FORMATS THE TIME
function format_time() {
    MINS=$(((${1}-${2})/60))
    SECS=$(((${1}-${2})%60))
    if [[ ${MINS} -ge 60 ]]; then
        HOURS=$((${MINS}/60))
        MINS=$((${MINS}%60))
    fi

    if [[ ${HOURS} -eq 1 ]]; then
        TIME_STRING+="1 HOUR, "
    elif [[ ${HOURS} -ge 2 ]]; then
        TIME_STRING+="${HOURS} HOURS, "
    fi

    if [[ ${MINS} -eq 1 ]]; then
        TIME_STRING+="1 MINUTE"
    else
        TIME_STRING+="${MINS} MINUTES"
    fi

    if [[ ${SECS} -eq 1 && -n ${HOURS} ]]; then
        TIME_STRING+=", AND 1 SECOND"
    elif [[ ${SECS} -eq 1 && -z ${HOURS} ]]; then
        TIME_STRING+=" AND 1 SECOND"
    elif [[ ${SECS} -ne 1 && -n ${HOURS} ]]; then
        TIME_STRING+=", AND ${SECS} SECONDS"
    elif [[ ${SECS} -ne 1 && -z ${HOURS} ]]; then
        TIME_STRING+=" AND ${SECS} SECONDS"
    fi

    echo ${TIME_STRING}
}


################
#              #
# SCRIPT START #
#              #
################

# START TRACKING TIME
START=$( date +%s )

for FOLDER in ${SUBS_REPOS}; do
    # PRINT TO THE USER WHAT WE ARE DOING
    newLine; echoText "Merging ${FOLDER}"

    # SHIFT TO PROPER FOLDER
    cd ${SOURCE_DIR}/${FOLDER}

    # SET PROPER URL
    if [[ ${FOLDER} == ".repo/manifests" ]]; then
        URL=android
    else
        URL=android_$( echo ${FOLDER} | sed "s/\//_/g" )
    fi

    # FETCH THE REPO
    git fetch https://github.com/LineageOMS/${URL} cm-14.1

    # GIT GYMNASTICS (GETS MESSY, BEWARE)
    # FIRST HASH WILL ALWAYS BE THE FETCH HEAD
    FIRST_HASH=$(git log --format=%H -1 FETCH_HEAD)

    # SECOND HASH WILL BE THE LAST THING I COMMITTED
    NUMBER_OF_COMMITS=$(( $( git log --format=%H --committer="Nathan Chancellor" FETCH_HEAD | wc -l ) - 1 ))
    SECOND_HASH=$( git log --format=%H --committer="Nathan Chancellor" FETCH_HEAD~${NUMBER_OF_COMMITS}^..FETCH_HEAD~${NUMBER_OF_COMMITS} )

    # PICK THE COMMITS
    git cherry-pick --abort
    git cherry-pick ${SECOND_HASH}^..${FIRST_HASH}

    # ADD TO RESULT STRING
    if [[ $? -ne 0 ]]; then
        RESULT_STRING+="${FOLDER}: ${RED}FAILED${RESTORE}\n"
    else
        RESULT_STRING+="${FOLDER}: ${GREEN}SUCCESS${RESTORE}\n"
    fi
done

# SHIFT BACK TO THE TOP OF THE REPO
cd ${SOURCE_DIR}

# SYNC THEME INTERFACER REPO
newLine; echoText "Syncing packages/apps/ThemeInterfacer"
repo sync packages/apps/ThemeInterfacer

# PRINT RESULTS
echoText "RESULTS"
echo -e ${RESULT_STRING}

# STOP TRACKING TIME
END=$( date +%s )

# PRINT RESULT TO USER
echoText "SCRIPT COMPLETED!"
echo -e ${RED}"TIME: $(format_time ${END} ${START})"${RESTORE}; newLine
