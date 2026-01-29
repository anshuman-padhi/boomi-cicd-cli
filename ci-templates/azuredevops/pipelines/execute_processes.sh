#!/bin/bash
cd ${SCRIPTS_HOME}
export atomNameBackup=${atomName}
for componentId in $(echo $componentIds | sed "s/,/ /g")
do
    export processName=${componentId}
    export atomName=${atomNameBackup}
    export atomType='*'
    echo Executing process "${processName}"
    source bin/executeProcess.sh processName="${processName}" atomName="${atomName}" componentId="${componentId}"
done
