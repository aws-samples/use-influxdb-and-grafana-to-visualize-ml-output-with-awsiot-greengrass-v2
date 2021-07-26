#!/bin/bash
# ==================================================================================
# Srikanth Kodali - @skkodali
# ==================================================================================

_setEnv()
{
  AWS="aws"
  DEV="dev"
  PRD="prd"
  DEV_IOT_THING_GROUP="DemoJetsonGroup"
  AWS_ACCOUNT_NUMBER="593512547852"
  AWS_REGION="us-west-2"
  ROLE_ARN="arn:aws:iam::593512547852:role/admin"
  NEXT_VERSION="1.0.0"
  COMPONENT_NAME="inferencing-model"
  CURRENT_VERSION_FILE="CURRENT_VERSION_FILE.txt"
  S3_BUCKET="sagemaker-us-west-2-593512547852"
  S3_KEY="artifacts"
  COMPILATION_NAME="TorchVision-ResNet18-Neo-2021-07-23-18-08-34-754"
  S3_PATH="s3://${S3_BUCKET}/${S3_KEY}/${COMPONENT_NAME}"
  SRC_FOLDER="src"
  ARTIFACTS_ARCHIVE_FILE_NAME="inferencing-model"
  MAIN_ARTIFACT_FILE="inference.py"
  MODEL_NAME='model'
  NEO_COMPILED_MODEL_PATH="s3://$S3_BUCKET/$COMPILATION_NAME/output/model-LINUX_X86_64.zip"
  DEPLOYMENT_CONFIG_TEMPLATE_FILE="deployment-configuration-template.json"
  DEPLOYMENT_CONFIG_FILE="deployment-configuration.json"
  index_val=-1
  c_index_val=-1
}

_exportAWSCreds()
{
    export AWS_ACCESS_KEY_ID="AWS_ACCESS_KEY_ID"
    export AWS_SECRET_ACCESS_KEY="AWS_SECRET_ACCESS_KEY"
    export AWS_SESSION_TOKEN="AWS_SESSION_TOKEN"
    echo ""
}

_installSigil()
{
    curl -kL "https://github.com/gliderlabs/sigil/releases/download/v0.6.0/sigil_0.6.0_$(uname -sm|tr \  _).tgz" | sudo tar -zxC /usr/local/bin
    which sigil
}

_getCurrentVersion() 
{
    echo "Checking and reading the version file exists in the S3Path : ${S3_BUCKET}/${S3_KEY}/${COMPONENT_NAME}/${CURRENT_VERSION_FILE}"
    aws s3api head-object --bucket ${S3_BUCKET} --key ${S3_KEY}/${COMPONENT_NAME}/${CURRENT_VERSION_FILE} || not_exist=true
    if [ $not_exist ]; then
        echo "Version file does not exist in the path : ${S3_PATH}/${CURRENT_VERSION_FILE}"
        CURRENT_VERSION_NUMBER="1.0.1"
        echo "The current version is : ${CURRENT_VERSION_NUMBER}"
    else
        echo "Version file exist in the path : ${S3_BUCKET}/${S3_KEY}/${COMPONENT_NAME}/${CURRENT_VERSION_FILE}"
        aws s3api get-object --bucket ${S3_BUCKET} --key ${S3_KEY}/${COMPONENT_NAME}/${CURRENT_VERSION_FILE}  --range bytes=0-10000 current_version_file.txt
        CURRENT_VERSION_NUMBER=$(cat current_version_file.txt | head -1)
        echo "The current version is : ${CURRENT_VERSION_NUMBER}"
    fi
}

_getNextVersion() 
{
  DELIMETER="."
  target_index=${2}
  #full_version=($(echo "$1" | tr '.' '\n'))
  full_version=""
  IFS='.' read -r -a full_version <<< "$1"
  #declare -a full_version=($(echo "$1" | tr "$DELIMETER" " "))
  for index in ${!full_version[@]}; do
    if [ $index -eq $2 ]; then
      local value=full_version[$index]
      value=$((value+1))
      full_version[$index]=$value
      break
    fi
  done
  NEXT_VERSION=`echo $(IFS=${DELIMETER} ; echo "${full_version[*]}")`
}

_compressArtifactsAndPushToCloud()
{
  SRC_FOLDER_ARG=$1
  PRJ_ARG=$2
  PWDIR=`pwd`
  echo $PWDIR
  cd ../${SRC_FOLDER_ARG}
  echo $PRJ_ARG
  zip -r ${PRJ_ARG}.zip .
  ls -ltra
  ${AWS} s3 cp ${PRJ_ARG}.zip ${S3_PATH}/${NEXT_VERSION}/
  cd ${PWDIR}
  ls -ltra
}

_create_gg_component_in_cloud()
{
  REC_FILE_ARG=$1
  RECIPE_URI="fileb://${REC_FILE_ARG}"
  echo "Creating components in the cloud."
  #RES=`${AWS} greengrassv2 create-component-version --inline-recipe ${RECIPE_URI} --region ${AWS_REGION}`
  ARN=$(${AWS} greengrassv2 create-component-version --inline-recipe ${RECIPE_URI} --region ${AWS_REGION} | jq -r ".arn")
  echo "ARN is : "
  echo ${ARN}
  AWS_ACCOUNT_NUM=`echo ${ARN} | cut -d ":" -f 5`
  #${AWS} greengrassv2 describe-component --arn "" --region ${AWS_REGION}
}

_prepare_deployment_config_file()
{
  sigil -p -f ${DEPLOYMENT_CONFIG_TEMPLATE_FILE} \
    component_name=$COMPONENT_NAME \
    component_version_number=${NEXT_VERSION} > ${DEPLOYMENT_CONFIG_FILE}
}

_get_index_value_from_array()
{
  comp_ver_array="$1"
  echo "${!comp_ver_array[@]}"
  for i in "${!comp_ver_array[@]}";
  do
     echo "In for loop : ${i}"
     echo "${comp_ver_array[$i]}"
     echo "${COMPONENT_NAME}"
     if [[ "${comp_ver_array[$i]}" = "${COMPONENT_NAME}" ]]; then
         echo "MATCH FOUND AT : ${i}";
         index_val=${i}        
         break;
     fi
  done 
}

_get_index_value_from_array_with_comp_name()
{
  local c_name="$1"
  shift
  local c_ver_array=("$@")
  #echo "In the function : count is : ${!c_ver_array[@]}"
  #echo "In the function : ${c_ver_array[@]}"
  for i in "${!c_ver_array[@]}";
  do
     if [[ "${c_ver_array[$i]}" = "${c_name}" ]]; then
         echo "MATCH FOUND AT : ${i}";
         c_index_val=${i}        
         break;
     fi
  done 
}

_prepare_deployment_config_file_based_on_deployment_name()
{
  DEPLOY_FILE_ARG=$1
  COMP_NAME=$2
  #COMP_VERSION=$3
  
  THING_GROUP_ARN="arn:aws:iot:${AWS_REGION}:${AWS_ACCOUNT_NUMBER}:thinggroup/${DEV_IOT_THING_GROUP}"
  deployment_id=`aws greengrassv2 list-deployments --target-arn ${THING_GROUP_ARN} | jq -r '.deployments[]' | jq -r .deploymentId`
  echo "Deployment Id is : ${deployment_id}"

  if [[ -z "${deployment_id}" ]]; then
    echo "There is no deployment for this thinggroup : ${DEV_IOT_THING_GROUP} yet."
    STR1='{"'
    STR2=${COMP_NAME}
    STR3='": {"componentVersion": '
    STR4=${NEXT_VERSION}
    STR5='}}'
    NEW_CONFIG_JSON=$STR1$STR2$STR3\"$STR4\"$STR5
    echo ${NEW_CONFIG_JSON}
  else
    COMP_VERSION=`aws greengrassv2 get-deployment --deployment-id ${deployment_id} | jq .'components' | jq '."'"${COMP_NAME}"'"' | jq -r ."componentVersion"`
    if [[ ! ${COMP_VERSION} = "null" ]]; then
      _getNextVersion ${COMP_VERSION} 2
    fi
    #echo $NEXT_VERSION
    NEW_CONFIG_JSON=`aws greengrassv2 get-deployment --deployment-id ${deployment_id} | jq .'components' | jq 'del(."$COMP_NAME")' | jq  '. += {"'"$COMP_NAME"'": {"componentVersion": "'"$NEXT_VERSION"'"}}'`
  fi
  FINAL_CONFIG_JSON='{"components":'$NEW_CONFIG_JSON'}'
  #echo $FINAL_CONFIG_JSON
  echo $(echo "$FINAL_CONFIG_JSON" | jq '.') > ${DEPLOY_FILE_ARG}
  cat ${DEPLOY_FILE_ARG} | jq
}

_deploy_configuration_on_devices() 
{
  echo "ARN is in deployment : ${ARN}"
  CONFIG_FILE_ARG=$1
  CONFIG_URI="fileb://${CONFIG_FILE_ARG}"
  THING_GROUP_ARN="arn:aws:iot:${AWS_REGION}:${AWS_ACCOUNT_NUM}:thinggroup/${DEV_IOT_THING_GROUP}"
  #aws greengrassv2 create-deployment --target-arn "arn:aws:iot:us-east-1:1233123123:thinggroup/ggv2-arm-tc-apps-ec2-group" --cli-input-json file://deployment_configuration.json --region us-east-1
  ${AWS} greengrassv2 create-deployment --target-arn ${THING_GROUP_ARN} --cli-input-json ${CONFIG_URI} --region ${AWS_REGION} --deployment-policies failureHandlingPolicy=DO_NOTHING
}

_updateTheVersionInFileInS3() 
{
  echo "Updating the version in the file."
  echo ${NEXT_VERSION} > ${CURRENT_VERSION_FILE}
  cat ${CURRENT_VERSION_FILE}
  aws s3 cp ${CURRENT_VERSION_FILE} ${S3_PATH}/${CURRENT_VERSION_FILE}
}

########################## MAIN ###############################
#
###############################################################
include_public_comps=true 
_setEnv
_exportAWSCreds
#_installSigil
_getCurrentVersion
_getNextVersion ${CURRENT_VERSION_NUMBER} 2
RECIPE_FILE_NAME="${COMPONENT_NAME}-${NEXT_VERSION}.yaml"
PREVIOUS_RECIPE_FILE_NAME="${COMPONENT_NAME}-${CURRENT_VERSION_NUMBER}.yaml"

echo '!!!!!!!!!!!!!!!!!!!!!!!!'
echo ${COMPONENT_NAME}
echo ${NEXT_VERSION}
echo ${SRC_FOLDER}
echo ${RECIPE_FILE_NAME}
echo '!!!!!!!!!!!!!!!!!!!!!!!!'


## Removing old recipe file from the local disk
if test -f "${PREVIOUS_RECIPE_FILE_NAME}"; then
    echo "Previous version recipe file : ${PREVIOUS_RECIPE_FILE_NAME} exists. Removing it from local disk."
    rm ${PREVIOUS_RECIPE_FILE_NAME}
fi

_compressArtifactsAndPushToCloud ${SRC_FOLDER} ${ARTIFACTS_ARCHIVE_FILE_NAME}

sigil -p -f recipe-file-template.yaml s3_path=${S3_PATH} \
    next_version=${NEXT_VERSION} \
    component_name=$COMPONENT_NAME \
    component_version_number=${NEXT_VERSION} \
    artifacts_zip_file_name=${ARTIFACTS_ARCHIVE_FILE_NAME} \
    artifacts_entry_file=${MAIN_ARTIFACT_FILE} \
    compiled_model_path=${NEO_COMPILED_MODEL_PATH} \
    model_name=${MODEL_NAME}> ${RECIPE_FILE_NAME}

echo "======== Generated recipe file is : ========"
cat ${RECIPE_FILE_NAME}
echo "======== End of recipe file : =============="

_create_gg_component_in_cloud ${RECIPE_FILE_NAME}
_prepare_deployment_config_file_based_on_deployment_name ${DEPLOYMENT_CONFIG_FILE} ${COMPONENT_NAME}
_deploy_configuration_on_devices ${DEPLOYMENT_CONFIG_FILE}
_updateTheVersionInFileInS3