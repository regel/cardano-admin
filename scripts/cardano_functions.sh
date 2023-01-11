
# checkError function to check if a command exits with error code
# Accepts one parameter: the exit code of the command
checkError() {
  # check if exit code is not 0
  if [[ $1 -ne 0 ]]; then
      # Print error message on stderr
      echo -e "\n\n\e[35mERROR (Code $1) !\e[0m\n" >&2
      exit $1
  fi
}

# file_lock function to set permissions to read-only
# Accepts one parameter: the file name
file_lock() {
  # check if the file exists
  if [ -f "$1" ]; then
      # set permissions to read-only
      chmod 400 "$1"
  fi
}

# file_unlock function to set permissions to read-write
# Accepts one parameter: the file name
file_unlock() {
  # check if the file exists
  if [ -f "$1" ]; then
      # set permissions to read-write
      chmod 600 "$1"
  fi
}

set_addrformat() {
  if [[ -z "$NETWORK" || "$NETWORK" == "mainnet" ]]; then
    addrformat="--mainnet"
  elif [[ "$NETWORK" == "preprod" || "$NETWORK" == "testnet" ]]; then
    addrformat="--testnet-magic 1"
  else
    echo "ERROR: Invalid value for NETWORK environment variable" >&2
    exit 1
  fi
}

# Check for existing files and exit if present
check_existing_file() {
  if [ -f "$1" ]; then
      echo "ERROR: $1 already exists, please use a different name or delete the file" >&2
      exit 2
  fi
}

# vault_write function
#
# Use the vault cli to write the given secret value to the specified path in vault
#
# parameters
#   $1: path to write the secret to (e.g. "secret/myapp/payment_vkey")
#   $2: value of the secret to write (e.g. "abcdefghijklmnopqrstuvwxyz")
#
# return
#   0 on success
#   non-zero on failure
vault_write() {
  local path=$1
  local key=$2
  local value=$3
  timeout 5 vault write "$path" "$key"="$value"
}


are_vault_credentials_defined() {
  if [[ -z "$VAULT_ADDR" || -z "$VAULT_TOKEN" ]]; then
      return 1
  else
      return 0
  fi
}

