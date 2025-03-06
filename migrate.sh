#!/bin/bash

set -o pipefail

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
    exit 0
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

trap 'echo "An error occurred. Exiting..."; exit 0;' ERR

printf "${_BOLD}${_MAGENTA}"
echo "+----------------------------------+"
echo "|                                  |"
echo "|  Railway Redis Migrator Script   |"
echo "|                                  |"
echo "+----------------------------------+"
printf "${_RESET}\n"

section "Validating environment variables"

section "Checking if OLD_URL is set and not empty"

# Validate that OLD_URL environment variable exists
if [ -z "$OLD_URL" ]; then
    error_exit "OLD_URL environment variable is not set."
fi

write_ok "OLD_URL correctly set"

section "Checking if NEW_URL is set and not empty"

# Validate that NEW_URL environment variable exists
if [ -z "$NEW_URL" ]; then
    error_exit "NEW_URL environment variable is not set."
fi

write_ok "NEW_URL correctly set"

# Query to check if there are any tables in the new database
output=$(echo 'DBSIZE' | redis-cli -u $NEW_URL)

if [[ "$output" == *"0"* ]]; then
  write_ok "The new database is empty. Proceeding with restore."
else
  if [ -z "$OVERWRITE_DATABASE" ]; then
    error_exit "The new database is not empty. Aborting migration.\nSet the OVERWRITE_DATABASE environment variable to overwrite the new database."
  fi
  write_warn "The new database is not empty. Found OVERWRITE_DATABASE environment variable. Proceeding with restore."
fi

section "Dumping database from OLD_URL" 

dump_file="/data/redis_dump.rdb"

redis-cli -u $OLD_URL --rdb "$dump_file" || error_exit "Failed to dump database from $OLD_URL."

write_ok "Successfully saved dump to $dump_file"

dump_file_size=$(ls -lh "$dump_file" | awk '{print $5}')

write_ok "Dump file size: $dump_file_size"

protocol_file="/data/redis_dump.protocol"

rdb -c protocol $dump_file > $protocol_file

write_ok "Converted rdb to protocol file"

section "Restoring database to NEW_URL"

# Restore that data to the new database
redis-cli -u $NEW_URL --pipe < $protocol_file

write_ok "Successfully restored database to NEW_URL"

section "Cleaning up"

if [ -f "$dump_file" ]; then
  write_ok "Removing $dump_file"

  rm -f $dump_file

  write_ok "Successfully removed $dump_file"
fi

if [ -f "$protocol_file" ]; then
  write_ok "Removing $protocol_file"

  rm -f $protocol_file

  write_ok "Successfully removed $protocol_file"
fi

write_ok "Successfully cleaned up"  

printf "${_RESET}\n"
printf "${_RESET}\n"
echo "${_BOLD}${_GREEN}Migration completed successfully${_RESET}"
printf "${_RESET}\n"
printf "${_RESET}\n"