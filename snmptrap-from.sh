#!/bin/bash -e
# This script allows to send SNMP v2 traps by spoofing the source address and pretends the trap
# come from another device, so the receiver MUST believe it comes from a real equipment.
# To spoof the source IP address of the the trap iptables is used.
# For this reason it is required to run this script as 'root'.
#
# This script is originated from:
# http://www.net-snmp.org/wiki/index.php/TUT:source_spoofing

# Default build identifier set to snapshot

REQUIRED_USER="root"
USER=$(whoami)

# Error codes
E_ILLEGAL_ARGS=126
E_BASH=127
E_UNSUPPORTED=128


DST="127.0.0.1"
COMMUNITY="public"
VERSION="2c"
SNMP_TRAP_BIN=$(which snmptrap)

# Test if snmptrap binary is available
if [ ! -f "${SNMP_TRAP_BIN}" ]; then
  echo "SNMP trap tool is not available."
  echo "Please install Net-SNMP utilities."
  exit ${E_UNSUPPORTED}
fi

# Setting Postgres User and changing configuration files require
# root permissions.
if [ "${USER}" != "${REQUIRED_USER}" ]; then
  echo ""
  echo "This script requires root permissions to be executed."
  echo ""
  exit ${E_BASH}
fi

####
# Help function used in error messages and -h option
usage() {
  echo ""
  echo "Send SNMP trap from source."
  echo ""
  echo "    Example with trap with spoofed source 10.23.42.1:"
  echo "    ./snmptrap-from.sh 10.23.42.1 .1.3.6.1.4.1.2636.4.5.0.1 .1.3.6.1.4.1.2636.1.2.3.4 s 'just now!'"
  echo ""
  exit
}

if [ "$#" -lt 2 ]; then
  # No enough args given show usage
  usage
fi

SRC="${1}"
shift  # get rid of the first parameter (Source IP)
       # and let the snmptrap check the rest

# Rule insertion
iptables -t nat -A POSTROUTING -d "${DST}" -p udp --dport 162 -j SNAT --to "${SRC}"
if [ "$?" -ne 0 ]; then
  echo "iptables rules installation failed."
  echo "You probably did not supply a proper source IP address."
  echo "Please refer to the error messages from the iptables command above ..."

  # for extra safety !
  iptables -t nat -A POSTROUTING -d "${DST}" -p udp --dport 162 -j SNAT --to "${SRC}" &>/dev/null
  exit ${E_ILLEGAL_ARGS}
fi

# Send trap to destination
snmptrap -v "${VERSION}" -c "${COMMUNITY}" "${DST}" '' "$@"

RESULT=$? # need for sleep later
if [ ${RESULT} -ne 0 ]; then
  echo "snmptrap command failed !!! Trap was not sent."
  echo "Please refer to the error messages from the snmptrap command above ..."
  exit ${E_ILLEGAL_ARGS}
else
  echo "Command OK. It was sent as:"
  echo "snmptrap $TRAP_FIXED_PARAMS $TRAP_RECEIVER '' \"$@\""
fi

# Leave some time to be sure snmptrap went thru iptables filters
[ ${RESULT} -eq 0 ] && sleep 2

# Remove the current rules
iptables -t nat -D POSTROUTING -d "${DST}" -p udp --dport 162 -j SNAT --to "${SRC}"
if [ $? -ne 0 ]; then
  echo "Error during removing the iptables rules"
  exit ${E_ILLEGAL_ARGS}
fi

exit 0
