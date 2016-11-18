#!/bin/bash 

# This script was inspired by the hook from https://gist.github.com/jreinert/49aca3b5f3bf2c5d73d8
# but specifically implemented for DigitalOcean's v2 rest api.  A signficant
# difference is that the script does not put the TXT record on the primary domain
# but rather the subdomain.  This means the name for the TXT record always
# remains _acme-challenge. instead of being _acme-challenge.<subdomain>.  
# Note the dependency on both curl and jq
# Finally, there is no affiliation with the DigitalOcean corporation and 
# absolutely no guarantees of any kind.  If you use this software you do so at your
# own risk.  
# The license for the use of this software is already specified
# under the general license for dehyradated.

clean_challenge(){
  curl -X DELETE -H "Content-Type: application/json" -H "Authorization: Bearer $DO_API_TOKEN" "https://api.digitalocean.com/v2/domains/${FQ_DOMAIN}/records/$1"
}

deploy_challenge(){

  local existing_domain 
  existing_domain=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $DO_API_TOKEN" "https://api.digitalocean.com/v2/domains/${FQ_DOMAIN}" | jq '.' | grep \"${FQ_DOMAIN}\")
  if [ "$existing_domain" == "" ]
  then
    echo "Existing domain name does not exist"
    exit
  fi

  JSON="{\"type\":\"TXT\",\"name\":\"_acme-challenge.\",\"data\":\"${TOKEN}\",\"priority\":null,\"port\":null,\"weight\":null}"
  RESULT=$(curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $DO_API_TOKEN" -d $JSON "https://api.digitalocean.com/v2/domains/${FQ_DOMAIN}/records")
  
  local record_id 
  record_id=$(echo ${RESULT} |  jq '.domain_record' | jq '.id')
  echo $record_id
}

if [ "$#" -lt 2 ]
then
  echo "Parameters expected [deploy_challenge|clean_challenge] <fully qualified domain name> <ignored> <token>"
  echo "This will create the txt records and should be invoked by dehydrated."
  echo "Example usage: ./dehydrated --challenge dns-01 -k hooks/dns-01/digitalocean/digitaloceanhook.sh -c"
  echo "Please be sure that you have set the DO_API_TOKEN environment variable and that you have properly configured dehydrated before using this script."

  exit 1
fi

TMPDIR='/tmp/digitalocean-acme'
mkdir -p "$TMPDIR"
FQ_DOMAIN=$2
TOKEN=$4

if [[ -z "${FQ_DOMAIN/*.*.*/}" ]]; then
  DOMAIN=${FQ_DOMAIN#*.}
  SUBDOMAIN=${FQ_DOMAIN%%.*}
else
  DOMAIN=$FQ_DOMAIN
  SUBDOMAIN=''
fi

if [ "$DO_API_TOKEN" == "" ]
then
  echo "Did you forget to set the DO_API_TOKEN environment variable?"
  exit
fi


case $1 in
'deploy_challenge')
    deploy_challenge > "$TMPDIR/$2.id"
    ;;
'clean_challenge')
    clean_challenge "$(cat "$TMPDIR/$2.id")" || exit 1
    rm "$TMPDIR/$2.id"
    ;;
esac
