#!/bin/bash
### Get environment id from environment name ###
cd ${SCRIPTS_HOME}
source bin/queryEnvironment.sh env="$env" classification="*"
saveEnvId=${envId}
echo $saveEnvId
#importerParams="${AWS_REGION} boomi/${saveEnvId}"
importerParams="${AZURE_KEY_VAULT_NAME} ${saveEnvId}"
###

#az login --service-principal -u e00a4779-fe50-4d7e-b96f-49481cbdd7bc -p $AZURE_PASS --tenant 5ba5ef5e-3109-4e77-85bd-cfeb0d347e82
java -cp "$BOOMI_LIBRARIES/*" -Dimporter="${importer}" -DimporterParams="${importerParams}" -Dexporter="${exporter}" -DexporterParams="${outputFile}" com.boomi.proserv.security.secretmanager.BoomiSecretManager
