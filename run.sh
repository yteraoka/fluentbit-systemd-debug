#!/bin/bash

info(){
  echo $(date +%FT%T) $*
}

FLUENT_BIT_VERSION=${1:-1.4.6}
LOGGEN_TAG=1.0.0

echo "Using FluentBit ${FLUENT_BIT_VERSION}"

#
# build loggen docker image
#
docker image inspect loggen:${LOGGEN_TAG} > /dev/null 2>&1
if [ $? -ne 0 ] ; then
  (cd loggen; docker build -t loggen:${LOGGEN_TAG} .)
fi


#
# prepare
#
if [ ! -d "log-${FLUENT_BIT_VERSION}" ] ; then
  mkdir "log-${FLUENT_BIT_VERSION}" 
fi

if [ ! -d "log-${FLUENT_BIT_VERSION}/buffers" ] ; then
  mkdir "log-${FLUENT_BIT_VERSION}/buffers" 
fi

rm -f "log-${FLUENT_BIT_VERSION}/out.json" 
rm -fr "log-${FLUENT_BIT_VERSION}/buffers.saved" 


#
# Run FluentBit container
#
fluent_bit_id1=$(docker run --name fluent-bit -d --rm \
  -v $(pwd)/fluent-bit-${FLUENT_BIT_VERSION}.conf:/fluent-bit/etc/fluent-bit.conf:ro \
  -v $(pwd)/log-${FLUENT_BIT_VERSION}:/fluent-bit/log \
  -v /var/log:/var/log \
  fluent/fluent-bit:${FLUENT_BIT_VERSION})
info "Started fluent-bit container-id: $fluent_bit_id1"

sleep 3

#
# Run loggen container
#
loggen_id=$(docker run --name loggen1 --rm -d -e SLEEP_SEC=0.001 loggen:1.0.0)
info "Started loggen container-id: $loggen_id"

sleep 10


#
# Stop FluentBit container temporary
#
info "Stopping fluent-bit"
docker stop fluent-bit

echo
echo "=== FluentBit Container log BEGIN ==="
journalctl -u docker.service -b CONTAINER_ID_FULL=${fluent_bit_id1} -a 
echo "=== FluentBit Container log END ==="
echo


cursor=$(echo 'select cursor from in_systemd_cursor;' | sqlite3 log-${FLUENT_BIT_VERSION}/flb_docker.db)
updated=$(echo 'select updated from in_systemd_cursor;' | sqlite3 log-${FLUENT_BIT_VERSION}/flb_docker.db)
info "Get cursor from SQLite DB"
info "Saved Cursor: $cursor"
info "Saved At: $(date -d @$updated)"


echo
echo "ls -l log-${FLUENT_BIT_VERSION}/buffers/systemd.0/"
ls -l log-${FLUENT_BIT_VERSION}/buffers/systemd.0/
echo

# save buffer file for investigating
cp -r "log-${FLUENT_BIT_VERSION}/buffers" "log-${FLUENT_BIT_VERSION}/buffers.saved"


info "Restarting fluent-bit container"
fluent_bit_id2=$(docker run --name fluent-bit -d --rm \
  -v $(pwd)/fluent-bit-${FLUENT_BIT_VERSION}.conf:/fluent-bit/etc/fluent-bit.conf:ro \
  -v $(pwd)/log-${FLUENT_BIT_VERSION}:/fluent-bit/log \
  -v /var/log:/var/log \
  fluent/fluent-bit:${FLUENT_BIT_VERSION})

sleep 10

#
# Stop loggen container
#
info "Stopping loggen1 container"
docker stop loggen1

sleep 2

#
# Stop FluentBit container
#
info "Stopping fluent-bit container"
docker stop fluent-bit


#
# Retrieve logs from journald
#
journalctl -u docker.service -o json -b CONTAINER_ID_FULL=${loggen_id} | jq -r .MESSAGE > journald.out

#
# Retrieve logs from FluentBit output
#
jq -r "select(.CONTAINER_ID_FULL == \"${loggen_id}\") | .MESSAGE" log-${FLUENT_BIT_VERSION}/out.json > fluentbit.out


echo
info "Checking difference between journald and fluentbit out"
diff <(sort -n journald.out) <(sort -n fluentbit.out)
diff_rc=$?
echo

if [ $diff_rc -eq 0 ] ; then
  echo "OK no lost log"
  echo "Try again!"
else
  echo '< : only in journalctl output'
  echo '> : only in FluentBit out_file'
  echo
  echo "LOST RECORDS FOUND"
  echo
  diff <(sort -n journald.out) <(sort -n fluentbit.out) | grep '^<' | while read sign time seq; do
    #echo "journalctl -u docker.service -b CONTAINER_ID_FULL=${loggen_id} -b \"MESSAGE=$time $seq\" -o json"
    journalctl -u docker.service -b CONTAINER_ID_FULL=${loggen_id} -b MESSAGE="$time $seq" -o json | jq .
    echo
  done
  echo
  for buf in log-${FLUENT_BIT_VERSION}/buffers.saved/systemd.0/*.flb; do
    first=$(strings $buf | grep -A 1 ^MESSAGE | grep '^ ' | sort | head -n 1)
    last=$(strings $buf | grep -A 1 ^MESSAGE | grep '^ ' | sort | tail -n 1)
    echo "records in $buf"
    echo "$first"
    echo "  ..."
    echo "$last"
    echo
  done
  wc -l journald.out fluentbit.out
fi
