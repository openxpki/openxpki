#!/bin/bash
#
# sscep wrapper for forwarding a CSR via SCEP. It uses the 
# sscep client and manages the certificate handling as well.
#
# Some of this was taken from bulkenrollment/enrollrequests
#
# OPERATION:
#
#   The operation must be one of the following:
#
#       enroll
#
#           This requires the option '-c' and optionally, '-w' and
#           '-M' may be set. If sscep returns SUCCESS rather than
#           PENDING, the certificate is written to the file specified
#           in '-w'. The CSR filename is passed as an argument.
#
#       getcert DECIMAL-CERT-SN
#
#           This operation requires the '-c' and '-w' options, and
#           takes the decimal certificate serialnumber as an argument.
#           It fetches the requested certificate and writes it to
#           the file specified with '-w'.
#
#
# CONFIGURATION:
#
# The configuration file is a simple shell script that is sourced and 
# contains the following key=value pairs:
#
# For the PASS options, see the openssl -passin and -passout options.
#
#   SCEP_PASS_TYPE     One of 'file', 'env', or 'none'
#   SCEP_PASS_SOURCE    Filename or name of env var
#
#   SCEP_URL            URL of SCEP server to contact
#   SCEP_SIGN_KEY       Filename of key used to sign SCEP
#   SCEP_SIGN_CERT      Filename of cert used to sign SCEP
#
# Optionally, the following vars may be set:
#
#   SCEP_TIMEOUT        Timeout value in seconds for sscep commands

USAGE=<<EOF
USAGE:

  sscep-wrapper.sh OPTIONS OPERATION [ARGUMENT]

OPTIONS:

  -c <file>   Configuration file
  -w <file>   Write received certificate to this file
  -M key=val  Metadata to pass via sscep (multiple entries allowed)

EXAMPLES:

  sscep-wrapper.sh \
    -c /etc/sscep-wrapper.cfg \
    -w /tmp/new-cert-to-receive.pem \
    -M admin_cc=admin@openxpki.org \
    -M requester=some.user@openxpki.org \
    enroll \
    /tmp/new-request-to-process.csr

  sscep-wrapper.sh \
    -c /etc/sscep-wrapper.cfg \
    -w /tmp/new-cert-to-receive.pem \
    getcert \
    DECIMAL-CERT-SN 

EOF

while getopts ":c:w:M:" opt; do
    case $opt in
        c)  CFG_FILE="$OPTARG"
            ;;
        w)  CERT_OUT_FILE="$OPTARG"
            ;;
        M)  if [ -z "$METADATA" ]; then
                METADATA="$OPTARG"
            else
                METADATA="$METADATA&$OPTARG"
            fi
            ;;
        \?) echo "$USAGE"
            exit 1
            ;;
    esac
done
shift $(($OPTIND - 1 ))

function die {
    echo "ERR $0: $@" 1>&2
    exit 1
}

OPERATION="$1"
shift

case "$OPERATION" in
    enroll)
        CSR_FILE="$1"
        shift
        if [ -z "$CSR_FILE" ]; then
            die "No CSR file specified"
        fi
        ;;
    getcert)
        CERT_SN="$1"
        shift
        if [ -z "$CERT_SN" ]; then
            die "No CERT SN specified"
        fi
        if [ -z "$CERT_OUT_FILE" ]; then
            die "No CERT file specified"
        fi
        ;;
    *)
        die "$0: Error: command '$OPERATION' not supported"
        ;;
esac

if [ -z "$CFG_FILE" ]; then
    die "No configuration file specified"
fi

if [ ! -f "$CFG_FILE" ]; then
    die "Config file '$CFG_FILE' not found"
fi

source "$CFG_FILE"

if [ -z "$SCEP_PASS_TYPE" ]; then
    die "SCEP_PASS_TYPE not set"
fi

if [ -z "$SCEP_SIGN_KEY" ]; then
    die "SCEP_SIGN_KEY not set"
fi

if [ -n "$CGIPATH" ]; then
    export PATH="$CGIPATH"
fi

# Default to 5s timeout
: ${SCEP_TIMEOUT:="5"}

LOGFILE="/tmp/enroll-sscep-wrapper.log"

>"$LOGFILE"
echo "Started $0 at `date`" >> "$LOGFILE"
echo "SCEP ENV VARS:" >> "$LOGFILE"
set | grep ^SCEP >> "$LOGFILE"

if [ -z "$CACERTBASE" ]; then
  CACERTBASE="/tmp/enroller-scepcacert"
fi
POLLING_INTERVAL=3

############################################################

# NOTE: This is based on the enroll() from the batchenrollment scripts.
# It is modified to disregard the CERTFILE.

# Enroll specified request file with the SCEP server.
# The function prints one single line to stdout representing the status
# of the request
# reads global configuration options:
# SCEP_URL
# SIGNKEY 
# SCEP_SIGN_CERT   (optional)
# SIGNKEYPIN (optional)
# KEYPIN     (optional)
# 
checkcacerts() {
    # fetch CA certificates on first invocation
    [ -z "$CACERTBASE" ] && getcacerts
    if [ -z "$CACERTBASE" ]; then
        echo "ERROR: could not get CA certificates from SCEP server" | tee a "$LOGFILE" 1>&2
        return 1
    fi
    if [ ! -r "$CACERTBASE" -a ! -r "$CACERTBASE-0" ] ; then
	echo "ERROR Could not get CA Certificates from SCEP server [CACERTBASE=$CACERTBASE]" | tee -a "$LOGFILE" 1>&2
	return 1
    fi
}

enroll() {
    checkcacerts

    DIR=`dirname $1`

    REQUESTFILE="$1"
    CERTFILE=/dev/null

    if [ ! -r "$REQUESTFILE" ] ; then
	echo "ERROR Request file '$REQUESTFILE' is not readable" | tee -a "$LOGFILE" 1>&2
	return 1
    fi

    case "$SCEP_PASS_TYPE" in
        key|file)
            if [ -z "$SCEP_PASS_SOURCE" ]; then
                die "SCEP_PASS_SOURCE not set"
                                                                                                            fi
            PASS_IN="-passin \"$SCEP_PASS_TYPE\":\"$SCEP_PASS_SOURCE\""
            ;;
        *)
            PASS_IN=
            ;;
    esac

    TMPFILE=`mktemp /tmp/key.XXXXXX`
    #topurge $TMPFILE
    chmod 600 $TMPFILE
    if ! openssl rsa -in $SCEP_SIGN_KEY $PASS_IN -out $TMPFILE >/dev/null 2>&1; then
	echo "ERROR Incorrect PIN specified or error reading keyfile" | tee -a "$LOGFILE" 1>&2
	return 1
    fi
    SIGNKEY="$TMPFILE"

    SSCEP_OPT=""
    # option "verbose" || SSCEP_OPT=">/dev/null 2>&1"

    #[ -n "$SIGNKEY" ] && SSCEP_OPT="-K $SIGNKEY $SSCEP_OPT"
    #[ -n "$SCEP_SIGN_CERT" ] && SSCEP_OPT="-O $SCEP_SIGN_CERT $SSCEP_OPT"

    if [ -f "$CACERTBASE-0" ]; then
        CACERTFILE="$CACERTBASE-0"
    else
        CACERTFILE="$CACERTBASE"
    fi

    set -x
    if [ -n "$CERT_OUT_FILE" ]; then
        CERTFILE="$CERT_OUT_FILE"
    fi

    # METADATA might contain an '&', which is deadly for shell
    if [ -n "$METADATA" ]; then
        METAOPT="-M"
    fi

    enroll_out=`mktemp`
    sscep enroll -u $SCEP_URL -c "$CACERTFILE" \
        -r "$REQUESTFILE" \
        -k "$SIGNKEY" \
        -K "$SIGNKEY" \
        -O "$SCEP_SIGN_CERT" \
        -l "$CERTFILE" \
        $METAOPT "$METADATA" \
        -T $SCEP_TIMEOUT \
        -t $POLLING_INTERVAL -n 1 $SSCEP_OPT > "$enroll_out" 2>&1
    RC=$?
    set +x
    cat "$enroll_out" | tee -a "$LOGFILE"
    rm "$enroll_out"

    [ -n "$TMPFILE" ] && rm -f "$TMPFILE"

    case $RC in
	0)
	    echo "SUCCESS"
	    return 0
	    ;;
	2)
	    echo "FAILURE"
	    ;;
	3)
	    echo "PENDING"
	    ;;
	70)
	    echo "FAILURE BADALG"
	    ;;
	71)
	    echo "FAILURE BADMSGCHK"
	    ;;
	72)
	    echo "FAILURE BADREQ"
	    ;;
	73)
	    echo "FAILURE BADTIME"
	    ;;
	74)
	    echo "FAILURE BADCERTID"
	    ;;
	89)
	    echo "ERROR Network timeout"
	    ;;
	91)
	    echo "ERROR Could not generate selfsigned certificate"
	    ;;
	93)
	    echo "ERROR File handling error"
	    ;;
	95)
	    echo "ERROR Network sending message"
	    ;;
	97)
	    echo "ERROR PKCS7 processing"
	    ;;
	99)
	    echo "ERROR unset pkiStatus"
	    ;;
	*)
	    echo "ERROR (unknown error code $RC)"
	    ;;
    esac
	
    return $RC
}

getcert() {
    checkcacerts

    CERTFILE=/dev/null

#    if [ ! -r "$REQUESTFILE" ] ; then
#	echo "ERROR Request file '$REQUESTFILE' is not readable" | tee -a "$LOGFILE" 1>&2
#	return 1
#    fi

    case "$SCEP_PASS_TYPE" in
        key|file)
            if [ -z "$SCEP_PASS_SOURCE" ]; then
                die "SCEP_PASS_SOURCE not set"
                                                                                                            fi
            PASS_IN="-passin \"$SCEP_PASS_TYPE\":\"$SCEP_PASS_SOURCE\""
            ;;
        *)
            PASS_IN=
            ;;
    esac

    TMPFILE=`mktemp /tmp/key.XXXXXX`
    #topurge $TMPFILE
    chmod 600 $TMPFILE
    if ! openssl rsa -in $SCEP_SIGN_KEY $PASS_IN -out $TMPFILE >/dev/null 2>&1; then
	echo "ERROR Incorrect PIN specified or error reading keyfile" | tee -a "$LOGFILE" 1>&2
	return 1
    fi
    SIGNKEY="$TMPFILE"

    SSCEP_OPT=""
    # option "verbose" || SSCEP_OPT=">/dev/null 2>&1"

    #[ -n "$SIGNKEY" ] && SSCEP_OPT="-K $SIGNKEY $SSCEP_OPT"
    #[ -n "$SCEP_SIGN_CERT" ] && SSCEP_OPT="-O $SCEP_SIGN_CERT $SSCEP_OPT"

    if [ -f "$CACERTBASE-0" ]; then
        CACERTFILE="$CACERTBASE-0"
    else
        CACERTFILE="$CACERTBASE"
    fi


    enroll_out=`mktemp`
    timeout $SCEP_TIMEOUT sscep getcert \
        -u $SCEP_URL -c "$CACERTFILE" \
        -k "$SIGNKEY" \
        -s "$CERT_SN" \
	-w "$CERT_OUT_FILE" \
	-l "$SCEP_SIGN_CERT" \
        $SSCEP_OPT > "$enroll_out" 2>&1
    RC=$?
        
    cat "$enroll_out" | tee -a "$LOGFILE"
    rm "$enroll_out"
    [ -n "$TMPFILE" ] && rm -f "$TMPFILE"

    if [ "$RC" != 0 ]; then
        echo "ERROR Timeout running 'sscep getcert ...'" 1>&2
        exit 95
    fi

    return $RC
}


# fetch SCEP CA Certificates
getcacerts() {

    rm -f $CACERTBASE-[0-9]*

    SSCEP_OPT=""
    #option "verbose" || SSCEP_OPT=">/dev/null 2>&1"
    #eval sscep getca -u $SCEP_URL -c $CACERTBASE $SSCEP_OPT
    timeout $SCEP_TIMEOUT sscep getca -u $SCEP_URL -c $CACERTBASE $SSCEP_OPT
    getca_rc=$?
    if [ "$getca_rc" == 124 ]; then
        die "Timeout running 'sscep getca ...'"
    fi

}

############################################################
# MAIN
############################################################

# TODO: optimize so this is only called when 'sscep enroll' returns
# with erc 93, which means that it couldn't open the CA cert file.
getcacerts | tee -a "$LOGFILE" 1>&2

case "$OPERATION" in
    enroll)
        enroll "$CSR_FILE" 
        enroll_rc=$?

        if [ $enroll_rc == 93 ]; then
            getcacerts | tee -a "$LOGFILE" 1>&2
            # try again...
            enroll "$CSR_FILE" 
            enroll_rc=$?
        fi
        exit $enroll_rc
        ;;
    getcert)
        getcert "$CERT_SN"
        getcert_rc=$?
        exit $getcert_rc
        ;;
    *)
        die "$0: Error: command '$OPERATION' not supported"
        ;;
esac

