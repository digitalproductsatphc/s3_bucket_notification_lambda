#!/bin/bash

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
    -e | --events)
        EVENTS="$2"
        shift # past argument
        shift # past value
        ;;
    -l | --lambda-arn)
        LAMBDA_ARN="$2"
        shift # past argument
        shift # past value
        ;;
    -b | --bucket)
        BUCKET="$2"
        shift # past argument
        shift # past value
        ;;
    -p | --prefix)
        PREFIX="$2"
        shift # past argument
        shift # past value
        ;;
    -s | --suffix)
        SUFFIX="$2"
        shift # past argument
        shift # past value
        ;;
    -i | --id)
        ID="$2"
        shift # past argument
        shift # past value
        ;;
    -* | --*)
        echo "Unknown option $1"
        exit 1
        ;;
    *)
        POSITIONAL_ARGS+=("$1") # save positional arg
        shift                   # past argument
        ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

echo "EVENTS     = [${EVENTS}]"
echo "LAMBDA_ARN = ${LAMBDA_ARN}"
echo "BUCKET     = ${BUCKET}"
echo "PREFIX     = ${PREFIX}"
echo "SUFFIX     = ${SUFFIX}"
echo "ID         = ${ID}"

if [[ -n $1 && $1 == "get" ]]; then
    if [ -z "${BUCKET}" ]; then
        echo "missing a required argument (BUCKET)"
        exit 1
    fi

    # get all notification from that bucket
    aws s3api get-bucket-notification-configuration --bucket "${BUCKET}"

elif [[ -n $1 && $1 == "delete" ]]; then

    if [ -z "${BUCKET}" ] || [ -z "${ID}" ]; then
        echo "missing a required argument (BUCKET, ID)"
        exit 1
    fi

    # check id exists
    current=$(aws s3api get-bucket-notification-configuration --bucket "${BUCKET}" |
        jq -c "select(.LambdaFunctionConfigurations[] | select(.Id == \"${ID}\"))")
    if [ -z "${current}" ]; then
        echo "id does not exist, and therefore cannot be deleted"
        exit 1
    fi

    # delete notifications with the same ID
    aws s3api get-bucket-notification-configuration --bucket "${BUCKET}" |
        jq "del(.LambdaFunctionConfigurations[] | select(.Id == \"${ID}\"))" |
        xargs -0I{} aws s3api put-bucket-notification-configuration --bucket "${BUCKET}" --notification-configuration {}

elif [[ -n $1 && $1 == "deleteAll" ]]; then
    aws s3api put-bucket-notification-configuration --bucket="${BUCKET}" --notification-configuration='{"LambdaFunctionConfigurations": []}'

elif [[ -n $1 && $1 == "update" ]]; then
    if [ -z "${BUCKET}" ] || [ -z "${ID}" ] || [ -z "${EVENTS}" ] || [ -z "${LAMBDA_ARN}" ]; then
        echo "missing a required argument (BUCKET, ID, EVENTS, LAMBDA_ARN)"
        exit 1
    fi

    # make json string
    if [ -z "${PREFIX}" ] && [ -z "${SUFFIX}" ]; then
        json_string=".LambdaFunctionConfigurations += [{\"Id\": \"${ID}\",\"LambdaFunctionArn\": \"${LAMBDA_ARN}\",\"Events\": [\"${EVENTS}\"]}]"
    elif [ -z "${PREFIX}" ]; then
        json_string=".LambdaFunctionConfigurations += [{\"Id\": \"${ID}\",\"LambdaFunctionArn\": \"${LAMBDA_ARN}\",\"Events\": [\"${EVENTS}\"],\"Filter\": {\"Key\": {\"FilterRules\": [{\"Name\": \"Suffix\", \"Value\": \"${SUFFIX}\"}]}}}]"
    elif [ -z "${SUFFIX}" ]; then
        json_string=".LambdaFunctionConfigurations += [{\"Id\": \"${ID}\",\"LambdaFunctionArn\": \"${LAMBDA_ARN}\",\"Events\": [\"${EVENTS}\"],\"Filter\": {\"Key\": {\"FilterRules\": [{\"Name\": \"Prefix\", \"Value\": \"${PREFIX}\"}]}}}]"
    else
        json_string=".LambdaFunctionConfigurations += [{\"Id\": \"${ID}\",\"LambdaFunctionArn\": \"${LAMBDA_ARN}\",\"Events\": [\"${EVENTS}\"],\"Filter\": {\"Key\": {\"FilterRules\": [{\"Name\": \"Prefix\", \"Value\": \"${PREFIX}\"},{\"Name\": \"Suffix\", \"Value\": \"${SUFFIX}\"}]}}}]"
    fi

    # check id exists
    current0=$(aws s3api get-bucket-notification-configuration --bucket "${BUCKET}" | jq -c)
    current=$(echo ${current0} | jq -c "select(.LambdaFunctionConfigurations[] | select(.Id == \"${ID}\"))")
    if [ -z "${current}" ]; then
        # create
        echo "creating"
        echo "id does not exist, and therefore it will be created"
        if [ -z "${current0}" ]; then
            echo new
            # Save config to temp file
            echo "{${json_string}}" | sed 's/.LambdaFunctionConfigurations +=/"LambdaFunctionConfigurations":/' | jq -c > temp.json
            # Create bucket notification using config 
            aws s3api --debug put-bucket-notification-configuration --bucket "${BUCKET}" --notification-configuration file://temp.json
            # Cleanup temp file
            rm temp.json
        else
            echo "existing"
            # Save the processed JSON to a temporary file
            echo "${current0}" | jq -c "${json_string}" > temp.json

            # Read the JSON from the file and pass it to the AWS CLI command
            aws s3api --debug put-bucket-notification-configuration --bucket "${BUCKET}" --notification-configuration file://temp.json

            # Remove the temporary file
            rm temp.json
        fi
    else
        # update
        echo "${ID} already exists, updating"

        # Save the processed JSON to a temporary file
        aws s3api --debug get-bucket-notification-configuration --bucket "${BUCKET}" |
        jq "del(.LambdaFunctionConfigurations[] | select(.Id == \"${ID}\"))" |
        jq -c "${json_string}" > temp.json

        # Read the JSON from the file and pass it to the AWS CLI command
        aws s3api --debug put-bucket-notification-configuration --bucket "${BUCKET}" --notification-configuration file://temp.json

        # Remove the temporary file
        rm temp.json
    fi

else
    echo "argument needed (get, update, delete)"
    exit 1
fi

exit 0
