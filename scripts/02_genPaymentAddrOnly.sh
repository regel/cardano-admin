#!/bin/bash

set -euo pipefail

. /usr/local/lib/cardano_functions.sh

CARDANO_CLI=${CARDANO_CLI:-/opt/cardano-cli}
if ! command -v "$CARDANO_CLI" >/dev/null; then
    echo "Error: $CARDANO_CLI is not installed. Please install cardano-cli before running this script" >&2
    exit 2
fi

verbose=0

#check command line parameters
while getopts "v" opt; do
  case $opt in
    v)
      verbose=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND -1))

if [ $# -lt 1 ]; then
  echo "ERROR - Usage: $(basename $0) [-v] <AddressName>" >&2
  echo "Examples: $(basename $0) [-v] owner" >&2
  exit 1;
else
  addrName="$(dirname $1)/$(basename $1 .addr)";
  addrName=${addrName/#.\//};
fi

# Trap function to clean up in case of interruption (CTRL-C)
terminate(){
  if [[ $verbose -eq 1 ]]; then
    echo -e "... doing cleanup ... \e[0m"
  fi
  file_unlock "${addrName}.vkey"
  rm -f "${addrName}.vkey" 2> /dev/null
  file_unlock "${addrName}.skey"
  rm -f "${addrName}.skey" 2> /dev/null
  exit 1
}

trap terminate INT
trap terminate ERR

#warnings
if [ -f "${addrName}.vkey" ]; then 
  if [[ $verbose -eq 1 ]]; then
    echo -e "\e[35mWARNING - ${addrName}.vkey already present, delete it or use another name !\e[0m" >&2
  fi
  exit 2;
fi
if [[ -f "${addrName}.skey" ]]; then
  if [[ $verbose -eq 1 ]]; then
    echo -e "\e[35mWARNING - ${addrName}.skey/hwsfile already present, delete it or use another name !\e[0m" >&2
  fi
  exit 2;
fi
if [ -f "${addrName}.addr" ]; then 
  if [[ $verbose -eq 1 ]]; then
    echo -e "\e[35mWARNING - ${addrName}.addr already present, delete it or use another name !\e[0m" >&2
  fi
  exit 2;
fi

${CARDANO_CLI} address key-gen --verification-key-file ${addrName}.vkey --signing-key-file ${addrName}.skey
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock ${addrName}.vkey
file_lock ${addrName}.skey

if [[ ! -f "${addrName}.vkey" ]]; then
  echo "ERROR - ${addrName}.vkey is not present. Payment-verification-key-file is mandatory" >&2
  exit 1;
fi

${CARDANO_CLI} address build --payment-verification-key-file ${addrName}.vkey ${addrformat} > ${addrName}.addr
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_lock ${addrName}.addr

if [[ $verbose -eq 1 ]]; then
  echo -e "\e[0mPaymentOnly(Enterprise)-Address built: \e[32m ${addrName}.addr \e[90m"
  cat ${addrName}.addr
  echo
fi
