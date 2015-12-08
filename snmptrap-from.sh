#!/bin/bash
# ----------------------------------------------------------------------------------------
# This is a quick and dirty solution to allow sending snmp
# version 2 traps pretending that the trap comes from the equipment supposed
# to send it (The receiver MUST beleive that it comes from the real equipment).
#
# The only solution that was proposed (and possible) was source IP spoofing.
# As suggested by other contributors, the solution would be in using iptables
# (Mangle tables were proposed but this would not work) on the linux box
# where we originate the trap.
#
# The solution was to write a little front-end script that would take the required snmptrap
# parameters (the default values needed by Zeljko being hard coded in the script) + the
# required source IP address for the trap (the IP address that we will do spoofing with).
#
# The script must be run by 'root' user because it must manipulate the iptables.
# The snmptrap command path must be in the calling user $PATH variable.
#
# The script is overly simple and is certainly lacking other 'features'. It should, however,
# give you the idea ...
# ----------------------------------------------------------------------------------------

TRAP_RECEIVER="127.0.0.1"
TRAP_FIXED_PARAMS="-v 2c -c public"

# For some coloured outputs ....
ESC=`echo -e "\e"`
red="${ESC}[31m"
green="${ESC}[32m"
norm="${ESC}[0m"

# Must be run as root because it must modify ip tables
if [ `whoami` != "root" ]
then
  cat <<EOF
$red
Error:
You must be root to use this command !
Please execute 'sudo bash' first...
$norm
EOF
  exit 1
fi


if [ $# -lt 2 ]
then
  cat <<EOF
$red
Error:
This command requires arguments !
Arg 1: should be the trap source address (equipment address)
Arg 2 to Arg n: should be arguments valid for the 'snmptrap -v 2c' command
$norm
EOF
  exit 1
fi


# Simple, no checks on the parameter ! If it is not a proper IP, the iptables command will choke
# and give an error description.

SRC=$1
shift   # get rid of the first parameter (Source IP)
        # and let the snmptrap check the rest


# Rule insertion
iptables -t nat -A POSTROUTING -d $TRAP_RECEIVER -p udp --dport 162 -j SNAT --to $SRC
rc=$?

if [ $rc -ne 0 ]
then
  cat <<EOF
$red
Error:
iptables rules installation failed.
You probably did not supply a proper source IP address.
Please refer to the error messages from the iptables command above ...
$norm
EOF
  # for extra safety !
  iptables -t nat -A POSTROUTING -d $TRAP_RECEIVER -p udp --dport 162 -j SNAT --to $SRC &>/dev/null
  exit 1
fi

snmptrap $TRAP_FIXED_PARAMS $TRAP_RECEIVER '' "$@"
rc=$?

if [ $rc -ne 0 ]
then
  cat <<EOF
$red
Error:
snmptrap command failed !!! Trap was not sent.
Please refer to the error messages from the snmptrap command above ...
$norm
EOF
else
  cat <<EOF
$green
Command OK. It was sent as:

  snmptrap $TRAP_FIXED_PARAMS $TRAP_RECEIVER '' "$@"
$norm
EOF
fi

# Leave some time to be sure snmptrap went thru iptables filters
[ $rc -eq 0 ] && sleep 2

# Remove the current rules
iptables -t nat -D POSTROUTING -d ${TRAP_RECEIVER} -p udp --dport 162 -j SNAT --to $SRC

exit $rc
