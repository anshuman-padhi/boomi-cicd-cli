#!/bin/bash

source bin/common.sh
# get atom id of the by atom name
# mandatory arguments
unset version
ARGUMENTS=(componentId)
OPT_ARGUMENTS=version
inputs "$@"
handle_error "$?" "Failed to process input arguments" || return 1

log_info "Retrieving component: ${componentId} ${version:+(version: ${version})}"

if [ "" != "$version" ]
then
	version="~$version"
else
	version=""
fi

export URL="${baseURL}Component/${componentId}${version}"

getXMLAPI


cat "${WORKSPACE}"/out.xml | xmllint --format - > "${WORKSPACE}"/${componentId}.xml


clean

export version=${myversion}
