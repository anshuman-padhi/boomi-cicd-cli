#!/bin/bash

source bin/common.sh

# get atom id of the by atom name
# mandatory arguments
ARGUMENTS=(atomName cloudId)
inputs "$@"
handle_error "$?" "Failed to process input arguments" || return 1

log_info "Creating atom: ${atomName}"
 
saveAtomName="${atomName}"
source bin/queryAtom.sh atomName="${atomName}" atomType="*" atomStatus="*"

if [ "$?" -gt "0" ]
then
   return 255;
fi

ARGUMENTS=(atomName cloudId)
JSON_FILE=json/createAtom.json
URL=$baseURL/Atom
id=id
exportVariable=atomId
export atomName=${saveAtomName}

if [ -z "${atomId}" ] || [ "${atomId}" == "null" ] 
then 
	
	createJSON
	callAPI

fi

clean
handle_error "$ERROR" "Failed to create atom: ${atomName}" || return 1

log_info "Successfully created atom: ${atomName} (ID: ${atomId})"
