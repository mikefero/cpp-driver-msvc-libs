#!/bin/bash

##
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <http://unlicense.org/>
##

#Debug statements [if needed]
#set -x #Trace
#set -n #Check Syntax

WORKING_DIRECTORY="$(pwd)"
BASH_FILENAME="$(basename $0)"

DEFAULT_BOOST_VERSION=1.65.1

##
# Convert a passed in string to lowercase
#
# @param ${1} String to convert to lowercase
# @return String converted to lowercase
##
toLower() {
	local string="$1"
	echo "$string" | tr "[:upper:]" "[:lower:]"
}

#
# Print the usage of the script
#
# @param ${1} Exit code to use when exiting
#
printUsage() {
	printf "Usage: `basename $0` [OPTION...]\n\n"
	printf "    %-30s  %s\n" "--debug" "include debug libraries"
  printf "    %-30s  %s\n" "--version <version>" "version number to retrieve and archive"
  printf "    %-30s  %s\n" "" "(default: ${DEFAULT_BOOST_VERSION})"
	printf "    %-30s  %s\n" "--help" "display this message"
	exit $1
}

#
# Download and extract the Boost MSVC archive
#
# @param ${1} Boost version to download and extract
#
downloadAndExtractBoostArchive() {
  local version=${1}
  local file_version=$(echo ${version} | sed "s/\./_/g")

  # Clean old boost directories
  rm -rf /tmp/boost*

  # Download and extract boost archive in /tmp
  printf "Downloading Boost v${version}\n"
  wget https://downloads.sourceforge.net/project/boost/boost-binaries/${version}/boost_${file_version}-bin-msvc-all-32-64.7z -O /tmp/boost.7z -q --show-progress
  if [ ${?} -ne 0 ]
  then
    printf "Error occurred while download Boost\nScript will now exit.\n"
    exit 1
  fi
  printf "Extracting Boost v${version} ..."
  7z x /tmp/boost.7z -o/tmp > /dev/null
  if [ ${?} -eq 0 ]
  then
    printf " OK\n\n"
  else
    printf " FAILED\nScript will now exit.\n"
    exit 1
  fi

  # Remove downloaded boost archive
  rm -f /tmp/boost.7z
}

#
# Create the archives for the DataStax C/C++ driver
#
# @param ${1} True is debug libraries should be bundled; false otherwise
#
createArchives() {
  local debug_libraries=${1}
  local prefix="libboost_"
  local release_suffix="-*-mt-1_*.lib"
  local debug_suffix="-*-mt-gd-1_*.lib"
  local binaries=("atomic" "chrono" "date_time" "filesystem" "log_setup" "log" "regex" "system" "thread" "unit_test_framework")

  # Clean old archive builds
  rm -rf archives

  # Iterate over all the library directories
  local boost_dir=$(basename $(pwd))
  find lib* -prune -type d | while read msvc_dir
  do
    # Determine if we should short circuit (libs directory)
    if [ "${msvc_dir}" == "libs" ]
    then
      continue
    fi

    # Get the architecture and MSVC version
    local architecture=$(echo ${msvc_dir} | awk '{split($0, a, "-"); print a[1]}' | sed "s/lib//")
    local msvc_version=$(echo ${msvc_dir} | awk '{split($0, a, "-"); print a[3]}')

    # Determine if we should short circuit (unsupported MSVC)
    if [ "${msvc_version}" == "8.0" ] || [ "${msvc_version}" == "9.0" ]
    then
      continue
    fi

  
    # Create a directory for the archives
    printf "Preparing for MSVC %s-%s archive ..." "${msvc_version}" "${architecture}"
    mkdir -p archives/${msvc_dir}

    # Iterate over the binaries to keep and copy them to the temp directory
    for binary in "${binaries[@]}"
    do
	    local release="${prefix}${binary}${release_suffix}"
	    local debug="${prefix}${binary}${debug_suffix}"
      cp ${msvc_dir}/${release} archives/${msvc_dir}
      if [ ${?} -ne 0 ]
      then
        printf " FAILED\n"
        continue
      fi

      # Handle debug binaries if requested
      if [ "${debug_libraries}" == "true" ]
      then
        cp ${msvc_dir}/${debug} archives/${msvc_dir}
        if [ ${?} -ne 0 ]
        then
          printf " FAILED\n"
          continue
        fi
      fi
    done

    # Create a directory for the current MSVC version
    mkdir -p archives/${boost_dir}

    # Copy the header and license files
    cp -r boost archives/${boost_dir}
    if [ ${?} -ne 0 ]
    then
      printf " FAILED\n"
      continue
    fi
    cp LICENSE*.txt archives/${boost_dir}
    if [ ${?} -ne 0 ]
    then
      printf " FAILED\n"
      continue
    fi

    # Copy the already pruned binaries
    cp -r archives/${msvc_dir} archives/${boost_dir}
    if [ ${?} -eq 0 ]
    then
      printf " OK\n"
    else
      printf " FAILED\n"
      continue
    fi

    # Create the archive file
    pushd archives > /dev/null
    printf "Creating archive for MSVC %s-%s ..." "${msvc_version}" "${architecture}"
    7z a ${boost_dir}-bin-msvc-${msvc_version}-${architecture}.7z -r ${boost_dir} > /dev/null
    if [ ${?} -eq 0 ]
    then
      printf " OK\n"
    else
      printf " FAILED\n"
    fi
    rm -rf ${boost_dir}
    popd > /dev/null
  done
  
  # Create a directory for the final archive
  mkdir -p archives/${boost_dir}

  # Copy the header and license files
  cp -r boost archives/${boost_dir}
  cp LICENSE*.txt archives/${boost_dir}

  # Move the pruned library directories
  mv archives/lib* archives/${boost_dir}

  # Create the final archive file
  pushd archives > /dev/null
  printf "Creating archive for all MSVC versions ..."
  7z a ${boost_dir}-bin-msvc-all-32-64.7z -r ${boost_dir} > /dev/null
  if [ ${?} -eq 0 ]
  then
    printf " OK\n"
    rm -rf ${boost_dir}
    rm -rf lib*
  else
    printf " FAILED\n"
  fi
  popd > /dev/null
}

# Parse the command line arguments
BOOST_VERSION=${DEFAULT_BOOST_VERSION}
DEBUG=false
NUMOFARGS=$#
LOOPCOUNTER=0
if [ $NUMOFARGS -gt 0 ]
then
	#Loop through each argument
	for ((LOOPCOUNTER=0; LOOPCOUNTER < NUMOFARGS; ++LOOPCOUNTER))
	do
		#Get the current argument
		ARG=$(toLower ${1})
		shift

		if [ "${ARG}" == "--debug" ]
		then
      DEBUG=true
    elif [ "${ARG}" == "--version" ]
    then
      BOOST_VERSION=${1}
			shift
		elif [ "${ARG}" == "--help" ]
		then
			printUsage 0
		fi
	done
fi

# Determine if we should execute the script
if [ ! -d "${BOOST_VERSION}" ]
then
  # Download and extract the requested boost archive
  downloadAndExtractBoostArchive ${BOOST_VERSION}

  # Move to the extracted boost library directory
  pushd /tmp/boost_* > /dev/null

  # Create the archives
  createArchives ${DEBUG}

  # Move the archives to the working directory
  mkdir -p "${WORKING_DIRECTORY}/${BOOST_VERSION}"
  mv archives/*.7z "${WORKING_DIRECTORY}/${BOOST_VERSION}"
  printf "\nBoost archives are located in %s\n" "${WORKING_DIRECTORY}/${BOOST_VERSION}"

  # Move back to working directory
  popd > /dev/null
else
  printf "Archives already exist for Boost v${BOOST_VERSION}\n"
fi
