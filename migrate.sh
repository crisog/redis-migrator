#!/bin/bash

set -o pipefail

sleep 2

export TERM=ansi
_GREEN=$(tput setaf 2)
_BLUE=$(tput setaf 4)
_MAGENTA=$(tput setaf 5)
_CYAN=$(tput setaf 6)
_RED=$(tput setaf 1)
_YELLOW=$(tput setaf 3)
_RESET=$(tput sgr0)
_BOLD=$(tput bold)

# Function to print error messages and exit
error_exit() {
    printf "[ ${_RED}ERROR${_RESET} ] ${_RED}$1${_RESET}\n" >&2
    exit 1
}

section() {
  printf "${_RESET}\n"
  echo "${_BOLD}${_BLUE}==== $1 ====${_RESET}"
}

write_ok() {
  echo "[$_GREEN OK $_RESET] $1"
}

write_warn() {
  echo "[$_YELLOW WARN $_RESET] $1"
}

trap 'echo "An error occurred. Exiting..."; exit 1;' ERR

printf "${_BOLD}${_MAGENTA}"
echo "+----------------------------------+"
echo "|                                  |"
echo "|  Railway Redis Migration Script  |"
echo "|                                  |"
echo "+----------------------------------+"
printf "${_RESET}\n"

echo "For more information, see https://docs.railway.app/database/migration"
echo "If you run into any issues, please reach out to us on Discord: https://discord.gg/railway"
printf "${_RESET}\n"

section "Validating environment variables"

# Validate that PLUGIN_URL environment variable exists
if [ -z "$PLUGIN_URL" ]; then
    error_exit "PLUGIN_URL environment variable is not set."
fi

# Validate that PLUGIN_URL contains the string "containers"
# if [[ "$PLUGIN_URL" != *"containers-us-west"* ]]; then
#     error_exit "PLUGIN_URL is not a Railway plugin database URL as it does not container the string 'containers-us-west'"
# fi

# write_ok "PLUGIN_URL correctly set"

# Validate that NEW_URL environment variable exists
if [ -z "$NEW_URL" ]; then
    error_exit "NEW_URL environment variable is not set."
fi

write_ok "NEW_URL correctly set"

section "Checking if NEW_URL is empty"

# Query to check if there are any tables in the new database
output=$(echo 'DBSIZE' | redis-cli -u $NEW_URL 2>/dev/null)

if [[ "$output" == *"0"* ]]; then
  write_ok "The new database is empty. Proceeding with restore."
else
  if [ -z "$OVERWRITE_DATABASE" ]; then
    error_exit "The new database is not empty. Aborting migration.\nSet the OVERWRITE_DATABASE environment variable to overwrite the new database."
  fi
  write_warn "The new database is not empty. Found OVERWRITE_DATABASE environment variable. Proceeding with restore."
fi

section "Dumping database from PLUGIN_URL" 

# Run pg_dump on the plugin database
dump_file="redis_dump.rdb"
redis-cli -u $PLUGIN_URL --rdb "$dump_file" || error_exit "Failed to dump database from $PLUGIN_URL."

write_ok "Successfully saved dump to $dump_file"

dump_file_size=$(ls -lh "$dump_file" | awk '{print $5}')
write_ok "Dump file size: $dump_file_size"

protocol_file=redis_dump.protocol
rdb -c protocol $dump_file > $protocol_file

write_ok "Converted rdb to protocol file"

section "Restoring database to NEW_URL"

# Restore that data to the new database
redis-cli -u $NEW_URL --pipe < $protocol_file

write_ok "Successfully restored database to NEW_URL"

printf "${_RESET}\n"
printf "${_RESET}\n"
echo "${_BOLD}${_GREEN}Migration completed successfully${_RESET}"
printf "${_RESET}\n"
echo "Next steps..."
echo "1. Update your application's REDIS_URL environment variable to point to the new database."
echo '  - You can use variable references to do this. For example `${{ Redis.REDIS_URL }}`'
echo "2. Verify that your application is working as expected."
echo "3. Remove the legacy plugin and this service from your Railway project."

printf "${_RESET}\n"
