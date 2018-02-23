#!/usr/bin/env bash

# =====================================================
# cm-info.sh
# =====================================================
#
# Copyright 2017 Cloudera, Inc.
#
# DISCLAIMER
#
# Please note: This script is released for use "AS IS" without any warranties
# of any kind, including, but not limited to their installation, use, or
# performance. We disclaim any and all warranties, either express or implied,
# including but not limited to any warranty of noninfringement,
# merchantability, and/ or fitness for a particular purpose. We do not warrant
# that the technology will meet your requirements, that the operation thereof
# will be uninterrupted or error-free, or that any errors will be corrected.
#
# Any use of these scripts and tools is at your own risk. There is no guarantee
# that they have been through thorough testing in a comparable environment and
# we are not responsible for any damage or data loss incurred with their use.
#
# You are responsible for reviewing and testing any scripts you run thoroughly
# before use in any non-testing environment.

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -uo pipefail

# -------------------------------------------------------------------------
# Adapted from:
#   cm-info.sh (Cloudera internal github project - ps-latex-doc)

VER=1.0

function cm_api() {
    local path="$1"
    shift
    cm_api_base "$api_ver/$path" "$@"
}

function cm_api_base() {
    local path="$1"
    shift
    curl -k -s -u "$OPT_USER:$OPT_PASSWORD" "$OPT_URL/api/$path" "$@"
}

function info() {
    echo "$(date) [$(tput setaf 2)INFO $(tput sgr0)] $*"
}

function err() {
    echo "$(date) [$(tput setaf 1)ERROR$(tput sgr0)] $*"
}

function warn() {
    echo "$(date) [$(tput setaf 3)WARN $(tput sgr0)] $*"
}

function debug() {
    if [[ $DEBUG_MODE -eq 1 ]]; then
        echo "$(date) [$(tput setaf 2)DEBUG$(tput sgr0)] $*"
    fi
}

function die() {
    err "$@"
    exit 2
}

function validate_cm_url() {
    local url_test cm_output
    local regex='(http|https?)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'

    if [[ ${OPT_URL} =~ $regex ]]; then
        url_test=$(curl -k --silent --head --fail "${OPT_URL}")
        if [ ! -z "${url_test}" ]; then
            info "Cloudera Manager seems to be running"
        else
            die "Can't connect to Cloudera Manager. Check URL and firewalls."
        fi
    else
        err  "Invalid Cloudera Manager URL '$OPT_URL'"
        exit 1
    fi

    cm_output=$(curl -k -s -u "$OPT_USER:$OPT_PASSWORD" "$OPT_URL/api")
    if grep -q "Error 401 Bad credentials" <<< "$cm_output"; then
        die "Authentication to Cloudera Manager failed. Check username and password."
    fi
}

function validate_cluster_name() {
    local encoded_name=
    local cm_output=

    encoded_name=$(python -c "import urllib; print urllib.quote('''$1''')")
    cm_output=$(cm_api "clusters/$encoded_name")
    debug "validate_cluster_name::cm_output=$cm_output"

    if grep -q "Cluster '$1' not found" <<< "$cm_output"; then
        die "Cluster name '$1' is not found."
    elif ! grep -q "\"displayName:\" : \"$1\"" <<< "$cm_output"; then
        info "Cluster name '$1' is valid."
    else
        die "Unexpected output from CM."
    fi
}

function get_cluster_name() {
    local name=
    local cm_output=
    cm_output=$(cm_api "clusters" | grep "displayName" | head -1)
    echo "$cm_output" | awk -F '[:,]' '{print $2}' | sed -e 's/^[ \t]*//' -e 's/"//g'
}

function download_xml() {
    local encoded_name svctype svcname cm_output urlpath urltest zip_filename

    encoded_name=$(python -c "import urllib; print urllib.quote('''$OPT_CLUSTER''')")
    svctype=$(echo "$1" | awk '{print toupper($0)}')

    cm_output=$(cm_api "clusters/$encoded_name/services" | grep -B 1 "\"type\" : \"$svctype\"" | grep "name")
    debug "download_xml::cm_output=$cm_output"

    svcname=$(echo "$cm_output" | sed -e 's/[,:"]//g' | awk -F '[[:space:]]+' '{print $3}')

    if [[ -z $svcname ]]; then
        err "Service $1 is not found. Likely not deployed to the cluster."
    else
        urlpath="clusters/$encoded_name/services/$svcname"

        debug "download_xml::Service Name=$svcname"
        debug "download_xml::URL=$OPT_URL/api/$api_ver/$urlpath"

        zip_filename="${OPT_OUTPUTDIR}/${svcname}_${OPT_CLUSTER}.zip"

        debug "download_xml::dirpath=$zip_filename"

        curl -k -s -o "$zip_filename" -u "$OPT_USER:$OPT_PASSWORD" "$OPT_URL/api/$api_ver/$urlpath/clientConfig"
        info "Service $svcname client XML files downloaded to $zip_filename"
    fi
}

function usage() {
    local SCRIPT_NAME=
    SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
    echo
    echo "Cloudera Haoop Client XML Files Downloader v$VER"
    echo
    echo "$(tput bold)USAGE:$(tput sgr0)"
    echo "  ./${SCRIPT_NAME} [OPTIONS]"
    echo
    echo "$(tput bold)MANDATORY OPTIONS:$(tput sgr0)"
    echo "  $(tput bold)-h, --host $(tput sgr0)<arg>"
    echo "        Cloudera Manager URL (e.g. http://cm-mycluster.com:7180)."
    echo
    echo "  $(tput bold)-u, --user $(tput sgr0)<arg>"
    echo "        Cloudera Manager username."
    echo
    echo "$(tput bold)OPTIONS:$(tput sgr0)"
    echo "  $(tput bold)-p, --password $(tput sgr0)<arg>"
    echo "        Cloudera Manager password. Will be prompted if unspecified."
    echo
    echo "  $(tput bold)-c, --pwcmd $(tput sgr0)<arg>"
    echo "        Executable shell command that will output the Cloudera Manager password."
    echo
    echo "  $(tput bold)-s, --services $(tput sgr0)<arg>"
    echo "        CDH service to download the client configuration zip file."
    echo "        Possible values are $CDHSVC. Default is hdfs."
    echo
    echo "  $(tput bold)-o, --outputdir $(tput sgr0)<arg>"
    echo "        Directory to save the zip file containing the client configuration files." 
    echo "	  Default is current working dir."
    echo
    echo "  $(tput bold)-n, --cluster $(tput sgr0)<arg>"
    echo "        Export only for a specific cluster. If not specified, the first cluster"
    echo "        will be selected."
    exit 1
}

OPT_USAGE=
OPT_URL=
OPT_USER=
OPT_PASSWORD=
OPT_PWCMD=
OPT_SERVICE="hdfs"
OPT_OUTPUTDIR=$(pwd)
OPT_CLUSTER=

CDHSVC="hdfs, hive, yarn, spark and spark2"
DEBUG_MODE=0

if [[ $# -eq 0 ]]; then
    usage
    die
fi

while [[ $# -gt 0 ]]; do
    KEY=$1
    shift
    case ${KEY} in
        -h|--host)      OPT_URL="$1";       shift;;
        -u|--user)      OPT_USER="$1";      shift;;
        -p|--password)  OPT_PASSWORD="$1";  shift;;
        -c|--pwcmd)     OPT_PWCMD="$1";     shift;;
        -o|--outputdir) OPT_OUTPUTDIR="$1"; shift;;
        -s|--services)  OPT_SERVICE="$1";  shift;;
        -n|--cluster)   OPT_CLUSTER="$1";   shift;;
        --help)         OPT_USAGE=true;;
        *)              OPT_USAGE=true
                        err "Unknown option: ${KEY}"
                        break;;
    esac
done

if [[ -z ${OPT_URL} ]]; then
    die "Missing Cloudera Manager URL. See usage."
elif [[ -z ${OPT_USER} ]]; then
    die "Missing Cloudera Manager username. See usage."
elif [[ ${OPT_USAGE} ]]; then
    usage
elif [[ ${OPT_PWCMD} ]]; then
    if [[ -x ${OPT_PWCMD} ]]; then
        OPT_PASSWORD=$($(dirname "$OPT_PWCMD")/$(basename "$OPT_PWCMD"))
     else
        die "Unable to execute or find ${OPT_PWCMD}"
    fi
else
    if [[ -z ${OPT_PASSWORD} ]]; then
        read -r -s -p "Enter password: " OPT_PASSWORD
        echo
    fi
fi

validate_cm_url
api_ver=$(cm_api_base version)

if [[ -z ${OPT_CLUSTER} ]]; then
    #If no cluster is specified, retrieve name of first cluster
    OPT_CLUSTER=$(get_cluster_name)
    info "No cluster specified. Retrieved name of first cluster: $OPT_CLUSTER"
else
    info "Using cluster '$OPT_CLUSTER'"
fi

validate_cluster_name "$OPT_CLUSTER"

case ${OPT_SERVICE} in
    hdfs)   download_xml "HDFS"; ;;
    yarn)   download_xml "YARN"; ;;
    hive)   download_xml "HIVE"; ;;
    spark)  download_xml "SPARK_ON_YARN"; ;;
    spark2) download_xml "SPARK2_ON_YARN"; ;;
    *)      die "Do not understand service ${OPT_SERVICE}."
esac


