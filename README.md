# snmptrap-tester
This script can be used to simulate SNMP traps from certain devices. It allows also to spoof the source IP address of the UDP packet using iptables with NAT.

For this reason it is required to run this command as root user.

## Usage

    snmptrap-from.sh source-ip .1.3.6.1.4.1.18529.0.2 .1.3.6.1.4.1.18529.1 s 'some-string' .1.3.6.1.4.1.18529.2.0.0 s 'some-string' .1.3.6.1.4.1.18529.3 i some-integer
