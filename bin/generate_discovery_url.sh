#!/bin/bash -e

#note - it appears the discovery url needs to be regenerated per run
SCRIPT=`python -c "import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))" "${BASH_SOURCE:-$0}"`
DIR=$(dirname $(dirname $SCRIPT))

discovery_url=$(curl -s -w "\n" 'https://discovery.etcd.io/new?size=3')

sed -i'.bak' -e "s|DISCOVERY_URL|$discovery_url|" $DIR/config.tfvars

rm $DIR/config.tfvars.bak
