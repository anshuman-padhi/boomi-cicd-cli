#!/bin/bash

if [[ "$apiComponentIds" == "" ]]
then
  export componentsList="${componentIds}"
else
  export childs=""

  for apiComponentId in $(echo $apiComponentIds | sed "s/,/ /g")
  do
    #echo "##Checking API Service ${apiComponentId}"
    curl -s "${baseURL}/Component/${apiComponentId}" --header "Accept: application/xml" -u "${authToken}" > components.xml

    export new_childs=`xmllint --xpath '//@processId' components.xml | tr -d '\n' | xargs | sed 's/processId//g' | xargs | sed 's/[\"\=]//g' | xargs | sed -e 's/ /,/g'`
    export childs="${new_childs},${childs}"
  done

  export componentsList=`echo "${apiComponentIds},${childs},${componentIds}" | sed 's/,*\r*$//'`
fi
echo "##vso[task.setvariable variable=componentIds;isOutput=true]$componentsList"
#echo "##vso[task.setvariable variable=componentIds;isOutput=true]35c454fe-dfb2-41ec-815c-ad7d742c36a3,b5f1fee8-9ddd-4515-b7d9-5f2f4595a85e,51b2696b-89a2-4b6a-a30d-7e4c922777c1"