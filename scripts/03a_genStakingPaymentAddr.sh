#!/bin/bash

set -euo pipefail

. /usr/local/lib/cardano_functions.sh

CARDANO_CLI=${CARDANO_CLI:-/opt/cardano-cli}
if ! command -v "$CARDANO_CLI" >/dev/null; then
    echo "Error: $CARDANO_CLI is not installed. Please install cardano-cli before running this script" >&2
    exit 2
fi
VAULT=${VAULT:-/usr/bin/vault}
if ! command -v "$VAULT" >/dev/null; then
    echo "Error: $VAULT is not installed. Please install vault cli before running this script" >&2
    exit 2
fi

set_addrformat
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
terminate() {
  echo "Cleaning up ..."
  file_unlock "${addrName}.payment.vkey"
  rm -f "${addrName}.payment.vkey"  2>/dev/null
  file_unlock "${addrName}.payment.skey"
  rm -f "${addrName}.payment.skey" 2>/dev/null
  file_unlock "${addrName}.payment.addr"
  rm -f "${addrName}.payment.addr" 2>/dev/null
  file_unlock "${addrName}.staking.vkey"
  rm -f "${addrName}.staking.vkey"  2>/dev/null
  file_unlock "${addrName}.staking.skey"
  rm -f "${addrName}.staking.skey" 2>/dev/null
  file_unlock "${addrName}.staking.addr"
  rm -f "${addrName}.staking.addr" 2>/dev/null
  file_unlock "${addrName}.staking.cert"
  rm -f "${addrName}.staking.cert"  2>/dev/null
  exit 1
}
trap terminate INT ERR

check_existing_file "${addrName}.payment.vkey"
check_existing_file "${addrName}.payment.skey"
check_existing_file "${addrName}.payment.addr"
check_existing_file "${addrName}.staking.vkey"
check_existing_file "${addrName}.staking.skey"
check_existing_file "${addrName}.staking.addr"
check_existing_file "${addrName}.staking.cert"


create_payment_address() {
  local addrName=$1
  local addrformat=$2
  local vkey_file="${addrName}.payment.vkey"
  local skey_file="${addrName}.payment.skey"
  
  if ! check_existing_file "$vkey_file" "$skey_file"; then
    "$CARDANO_CLI" address key-gen --verification-key-file "$vkey_file" --signing-key-file "$skey_file"
    checkError "$?"
    file_lock "$vkey_file"
    file_lock "$skey_file"
    echo -e "\e[0mPayment(Base)-Verification-Key: \e[32m $vkey_file \e[90m"
    cat "$vkey_file"
    echo -e "\e[0mPayment(Base)-Signing-Key: \e[32m $skey_file \e[90m"
    cat "$skey_file"
    echo
  fi

  local addr_file="${addrName}.payment.addr"
  if ! check_existing_file "$addr_file"; then
    "$CARDANO_CLI" address build --payment-verification-key-file "$vkey_file" --staking-verification-key-file "${addrName}.staking.vkey" ${addrformat} > "$addr_file"
    checkError "$?"
    file_lock "$addr_file"
    echo -e "\e[0mPayment(Base)-Address built: \e[32m $addr_file \e[90m"
    cat "$addr_file"
    echo
  fi
}


create_staking_address() {
  local addrName=$1
  local addrformat=$2
  ${CARDANO_CLI} stake-address key-gen --verification-key-file "${addrName}.staking.vkey" --signing-key-file "${addrName}.staking.skey"
  if [[ $? -ne 0 ]]; then
      echo -e "\n\n\e[35mERROR (Code $?) creating Staking keypair !\e[0m\n" >&2
      exit $?
  fi
  file_lock ${addrName}.staking.vkey
  file_lock ${addrName}.staking.skey
  echo -e "\e[0mVerification(Rewards)-Staking-Key: \e[32m ${addrName}.staking.vkey \e[90m"
  cat ${addrName}.staking.vkey
  echo
  echo -e "\e[0mSigning(Rewards)-Staking-Key: \e[32m ${addrName}.staking.skey \e[90m"
  cat ${addrName}.staking.skey
  echo

  ${CARDANO_CLI} stake-address build --staking-verification-key-file "${addrName}.staking.vkey" ${addrformat} > "${addrName}.staking.addr"
  if [[ $? -ne 0 ]]; then
      echo -e "\n\n\e[35mERROR (Code $?) building Staking address !\e[0m\n" >&2
      exit $?
  fi
  file_lock ${addrName}.staking.addr
  echo -e "\e[0mStaking(Rewards)-Address built: \e[32m ${addrName}.staking.addr \e[90m"
  cat "${addrName}.staking.addr"
  echo

  ${CARDANO_CLI} stake-address registration-certificate --staking-verification-key-file "${addrName}.staking.vkey" --out-file "${addrName}.staking.cert"
  if [[ $? -ne 0 ]]; then
      echo -e "\n\n\e[35mERROR (Code $?) creating Staking certificate !\e[0m\n" >&2
      exit $?
  fi
  file_lock "${addrName}.staking.cert"
  echo -e "\e[0mStaking-Address-Registration-Certificate built: \e[32m ${addrName}.staking.cert \e[90m"
  cat "${addrName}.staking.cert"
  echo
}

create_payment_address "$addrName" "$addrformat"
create_staking_address "$addrName" "$addrformat"

if are_vault_credentials_defined; then
  vault_write secret/keys payment_vkey "$(cat ${addrName}.payment.vkey)"
  vault_write secret/keys payment_skey "$(cat ${addrName}.payment.skey)"
  vault_write secret/keys payment_addr "$(cat ${addrName}.payment.addr)"
  vault_write secret/keys staking_vkey "$(cat ${addrName}.staking.vkey)"
  vault_write secret/keys staking_skey "$(cat ${addrName}.staking.skey)"
  vault_write secret/keys staking_addr "$(cat ${addrName}.staking.addr)"
  vault_write secret/keys staking_addr "$(cat ${addrName}.staking.cert)"
fi
