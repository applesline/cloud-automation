#!/bin/bash
#
# Deploy data-ingestion-job into existing commons

# See cloud-automation/doc/kube-setup-data-ingestion-job.md for information on how to use this script

source "${GEN3_HOME}/gen3/lib/utils.sh"
gen3_load "gen3/gen3setup"

gen3 kube-setup-secrets

mkdir -p "$(gen3_secrets_folder)/g3auto/data-ingestion-job"
credsFile="$(gen3_secrets_folder)/g3auto/data-ingestion-job/data_ingestion_job_config.json"

if (! (g3kubectl describe secret data-ingestion-job-secret 2> /dev/null | grep config.js > /dev/null 2>&1)) \
  && [[ (! -f "$credsFile") && -z "$JENKINS_HOME" ]]; 
then
  cat - > "$credsFile" <<EOM
{
  "genome_bucket_gs_creds": {
    "type": "service_account",
    "project_id": "",
    "private_key_id": "",
    "private_key": "",
    "client_email": "",
    "client_id": "",
    "auth_uri": "",
    "token_uri": "",
    "auth_provider_x509_cert_url": "",
    "client_x509_cert_url": ""
  }, 
  "genome_bucket_aws_creds": {
    "aws_access_key_id": "",
    "aws_secret_access_key": ""
  },
  "local_data_aws_creds": {
    "aws_access_key_id": "",
    "aws_secret_access_key": "",
    "bucket_name": ""
  },
  "gcp_project_id": "",
  "github_user_email": "",
  "github_personal_access_token": "",
  "github_user_name": "",
  "git_org_to_pr_to": "",
  "git_repo_to_pr_to": ""
}
EOM
  gen3 secrets sync "initialize data-ingestion-job/data_ingestion_job_config.json"
fi

# Prep inputs to job

PHS_ID_LIST_PATH="$(gen3_secrets_folder)/g3auto/data-ingestion-job/phsids.txt"
DATA_REQUIRING_MANUAL_REVIEW_PATH="$(gen3_secrets_folder)/g3auto/data-ingestion-job/data_requiring_manual_review.tsv"
GENOME_FILE_MANIFEST_PATH="$(gen3_secrets_folder)/g3auto/data-ingestion-job/genome_file_manifest.csv"

argc=$#
argv=("$@")
for (( j=0; j < argc - 1; j++ )); do
  if [ "${argv[j]}" == "CREATE_GOOGLE_GROUPS" ]; then
    CREATE_GOOGLE_GROUPS="${argv[j+1]}"
  fi
done

g3kubectl delete configmap phs-id-list > /dev/null
g3kubectl delete configmap data-requiring-manual-review > /dev/null

if [ ! -f "$PHS_ID_LIST_PATH" ]; then
  echo "A file containing a list of study accessions was not found at $PHS_ID_LIST_PATH. Please provide one! Exiting."
  exit
fi
g3kubectl create configmap phs-id-list --from-file="$PHS_ID_LIST_PATH"

if [ -f "$DATA_REQUIRING_MANUAL_REVIEW_PATH" ]; then
  echo "Found a data_requiring_manual_review file at $DATA_REQUIRING_MANUAL_REVIEW_PATH; will incorporate these PHS IDs in extract creation."
  g3kubectl create configmap data-requiring-manual-review --from-file="$DATA_REQUIRING_MANUAL_REVIEW_PATH"
fi

add_genome_file_manifest_to_bucket() {
  echo "a"
  hostname="$(g3kubectl get configmap global -o json | jq -r .data.hostname)"
  echo "b"
  bucket_name=$(jq -r .local_data_aws_creds.bucket_name <<< "$credsFile")
  echo "c"
  if [ -z "$bucket_name" ]; then
    bucket_name="data-ingestion-${hostname//./-}"
  fi
  echo "creating $bucketname"
  gen3 s3 create "$bucketname"
  echo "d"
  jq ".local_data_aws_creds.bucket_name = \"$bucket_name\"" "$credsFile" > test2.json
  echo "e"
  aws s3 cp "$GENOME_FILE_MANIFEST_PATH" "s3://$bucket_name/genome_file_manifest.csv"
  echo "f"
  GENOME_FILE_MANIFEST_PATH="s3://$bucketname/genome_file_manifest.csv"
  echo "g"
  gen3 secrets sync "initialize data-ingestion-job/data_ingestion_job_config.json"
}

if [ -f "$GENOME_FILE_MANIFEST_PATH" ]; then
  while true; do
    read -p "Found a genome file manifest at $GENOME_FILE_MANIFEST_PATH. Would you like to use this file to skip the manifest creation step? " yn
    case $yn in
        [Yy]* ) add_genome_file_manifest_to_bucket; break;;
        [Nn]* ) GENOME_FILE_MANIFEST_PATH=''; break;;
        * ) echo "Please answer yes or no.";;
    esac
  done
fi

gen3 runjob data-ingestion CREATE_GOOGLE_GROUPS $CREATE_GOOGLE_GROUPS