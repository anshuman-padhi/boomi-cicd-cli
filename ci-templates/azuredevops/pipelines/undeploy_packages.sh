#!/bin/bash
cd ${SCRIPTS_HOME}
source ./bin/undeployPackages.sh env="${env}" componentIds="${componentIds}"
echo $deploymentId
