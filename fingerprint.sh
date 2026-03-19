#!/bin/bash
LOG="/var/log/fingerprint.log"
export VERBOSE=1

mylog() {

if [ "$VERBOSE" == 1 ]; then
echo "$(date): $*" >>$LOG
fi

}

eexit() {

# enable verbosity on critical error
VERBOSE=1
mylog "ERROR: $* exiting..." >>$LOG
exit 1

}

prereq_check() {

type pvesh   &>/dev/null                || eexit "pvesh not in path. uh-oh. this should not be. please make sure to run this as on a pve server"
type jq      &>/dev/null                || eexit "jq not in path. jq not installed?"
type openssl &>/dev/null                || eexit "openssl not in path. openssl not installed?"
[ $(id -u) -eq 0 ]                      || eexit "you need to be root, to run this"

}

export   LC_ALL=C
export     PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
export PBS_PORT=8007

main() {

prereq_check

mylog "updating all Fingerprints of all Storages with type PBS"

STORAGES="$(pvesh get /storage --output-format=json | jq -r '.[] | select(.type=="pbs") | .storage')"

for STORAGE in $STORAGES; do
    if [ -z "$STORAGE" ] ; then
    # empty storage variable, should not happen
    continue
    fi
    mylog "Found new PBS Storage: $STORAGE"

    # Get PBS-Server from storage configuration
    PBS_SERVER=$(pvesh get /storage/$STORAGE --output-format=json | jq -r '.server')
    if [ -z "$PBS_SERVER" ]; then
    mylog "PBS Storage $STORAGE has no configured Server, assume bad storage configuration, ignoring"
    continue
    fi
    mylog "Figured out PBS Backend Server: $PBS_SERVER"

    # figure out new fingerprint
    NEW_FINGERPRINT=$(openssl s_client -connect ${PBS_SERVER}:${PBS_PORT} -servername ${PBS_SERVER} </dev/null 2>/dev/null | \
  openssl x509 -noout -fingerprint -sha256 | cut -d'=' -f2)
    if [ -z "$NEW_FINGERPRINT" ] ; then
    mylog "Cannot figure out fingerprint from PBS Server $PBS_SERVER, not updating fingerprint"
    continue
    fi

    mylog "getting old fingerprint"
    OLD_FINGERPRINT="$(pvesh get /storage/$STORAGE --output-format=json | jq -r '.fingerprint')"

    if [ "$OLD_FINGERPRINT" == "$NEW_FINGERPRINT" ]; then
    mylog "fingerprint is ok and does not need to be updated"
    continue
    fi

    mylog "setting as new fingerprint $NEW_FINGERPRINT"
    # Fingerprint auf allen Nodes aktualisieren (clusterweit)
    if pvesh set /storage/$STORAGE --fingerprint "$NEW_FINGERPRINT" --quiet;then
    mylog "new fingerprint set successfully"
    fi
done

mylog "All PBS-Fingerprints within the Cluster had been updated."
}

main
