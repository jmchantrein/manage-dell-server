#!/bin/bash
# name: remote_racadm.sh
# author: Jean-Mathieu Chantrein https://github.com/jmchantrein
# Depend: sshpass package
# Successfull pass shellcheck

############
# FUNCTION #
############
usage ()
{
cat << EOF
This script allows to process racadm command on a set of remote dell server idracs without
have shared the public key of the server (i.e.: ssh login by password).

Use of --email-alert[1-3] enable all email alerts.

Idrac version 7 and later

usage: ./remote_racadm.sh -b | --base-plage-ip XXX.XXX.XXX. -i | --interval XX[-XX]
		# Setters configuration
		[ -a | --alert-enable ]
		[ -c | --dns-address2 ] address			 
		[ -d | --dns-address1 ] address
		[ -e | --test-alert-email ]
		[ -f | --alert-disable ]
		[ -h | --help ]
		[ -j | --disable-email-alert1 ]
		[ -k | --disable-email-alert2 ]
		[ -l | --disable-email-alert3 ]
		[ -m | --gw-address ] address
		[ -n | --ntp-server-address ] address
		[ -o | --web-server-time-out ] min
		[ -p | --idrac-password ]              # Deprecated, the password is requested to the prompt
		[ -q | --set-prefix-racname ]
		[ -r | --set-racname ]
		[ -s | --smtp-address ] address
		[ -t | --timezone ] Country/City
		[ -u | --idrac-user ]                  # Asked at the prompt if not informed
		[ -v | --dns-domain-name ] domain.name
		[ -w | --webserver-title-bar ]       
		[ -x | --email-alert1 ] email1@example.com
		[ -y | --email-alert2 ] email2@example.com
		[ -z | --email-alert3 ] email3@example.com

		# Getters configuration
		[ --get-alert-enable ]
		[ --get-dns-address2 ]
		[ --get-dns-address1 ]
		[ -g | --getractime ]
		[ --get-gw-address ]
		[ --get-ntp-server-address ]
		[ --get-web-server-time-out ]
		[ --get-racname ]
		[ --get-smtp-address ]
		[ --get-timezone ]
		[ --get-dns-domain-name ]
		[ --get-email-alert1 ]
		[ --get-email-alert2 ]
		[ --get-email-alert3 ]
		[ --LCD-display-racname ]

		# Server action
		[ --graceshutdown | --hardreset | --powercycle | --powerdown | --powerup | --powerstatus ] # Hardreset means reboot

Examples: 
	On a single server:

		# Set some parameters
		./remote_racadm.sh -u root -b 192.168.255. -i 254 --set-racname NAME_SERVER --webserver-title-bar
		
		# Set some parameters without any interaction
		./remote_racadm.sh -u root -p calvin -b 192.168.255. -i 254 --set-racname NAME_SERVER --webserver-title-bar

		# Get some information
		./remote_racadm.sh -u root -b 192.168.255. -i 254 --get-alert-enable --get-dns-address1 --getractime --get-gw-address --get-ntp-server-address --get-web-server-time-out --get-racname --get-smtp-address  --get-timezone  --get-dns-domain-name --get-email-alert1

	On a set of server:

		# Configuration
		./remote_racadm.sh -u root -b 192.168.255. -i 10-100 --gw-address 192.168.255.254 -a -d 8.8.8.8 --smtp-address smtp.example.com --set-prefix-racname NODE_ --LCD-display-racname -x bob@example.com --ntp-server-address 192.168.255.254 --timezone Europe/Paris
		# Idrac name will be NODE_10,NODE_11,...,NODE_100
		
		# Test email alert
		./remote_racadm.sh -u root -b 192.168.255. -i 10-100 --gw-address 192.168.255.254 --test-alert-email

		# Server action
		./remote_racadm.sh -u root -b 192.168.255. -i 10-100 --hardreset

Bugs known:
	The sending of a test email sometimes requires a latency between the time when we configure the idrac and the time when we do the test of sending mail.
	It's sometimes necessary to go through the web interface of the idrac to make the first test of sending email by hand ...

EOF

if [ ! "$(command sshpass)" ]; then
	cat << EOF
Warning:
	This script depend of sshpass package.
	It seems you don't have the sshpass package installed on your system or don't appear on your PATH environment variable.
	Please install sshpass package:

		On debian:
				apt-get install sshpass
	
		On centos:
				yum install sshpass
EOF
fi

exit 0
}

gestion_interval_ip ()
{
    local -r _arg=${1}
	# The 2 following variables are passed by reference (to avoid usage of global variable)
	local __num_begin=${2}
	local __num_end=${3}

    # Is it a machine or a set of machines ?
	local -r _pos_separateur=$(echo | awk '{ print index("'"${_arg}"'", "-")}')
	local _num_begin=""
    local _num_end=""
    if [ ! "${_pos_separateur}" -eq 0 ]; then
        _num_begin=$(echo | awk '{ print substr("'"${_arg}"'",1,"'"${_pos_separateur}"'"-1)}')
        _num_end=$(echo | awk '{ print substr("'"${_arg}"'","'"${_pos_separateur}"'"+1)}')
        # Inversion in the case where _num_begin > _num_end for the transition to seq
        if [ "${_num_begin}" -gt "${_num_end}" ]; then
            local -r _temp="${_num_begin}"
            _num_begin="${_num_end}"
            _num_end="${_temp}"
        fi
    else
        _num_begin="${_arg}"
        _num_end="${_arg}"
    fi

	# Assignment of the variables passed in parameters
	eval "$__num_begin"="${_num_begin}"
	eval "$__num_end"="${_num_end}"
}

main ()
{
# If no argument, output the usage command
if [ "${#}" -eq 0 ]; then
   	usage
fi

# The postfixed options by ":" are waiting for an argument
# Multiline mode for the following command does not work ...
OPTS=$(getopt -o a,b:,c:,d:,e,f,g,h,i:,j,k,l,m:,n:,o:,p:,q:,r:,s:,t:,u:,v:,w,x:,y:,z:	--long alert-enable,base-plage-ip:,dns-address2:,dns-address1:,test-alert-email,alert-disable,getractime,interval-ip:,disable-email-alert1,disable-email-alert2,disable-email-alert3,gw-address:,ntp-server-address:,web-server-time-out:,idrac-password:,set-prefix-racname:,set-racname:,smtp-address:,timezone:,idrac-user:,dns-domain-name:,webserver-title-bar,email-alert1:,email-alert2:,email-alert3:,get-alert-enable,get-dns-address2,get-dns-address1,get-gw-address,get-ntp-server-address,get-web-server-time-out,get-racname,get-smtp-address,get-timezone,get-dns-domain-name,get-email-alert1,get-email-alert2,get-email-alert3,LCD-display-racname,graceshutdown,hardreset,powercycle,powerdown,powerup,powerstatus --name "$(basename "$0")" -- "$@")


# We replace the positional arguments with those of $OPTS
eval set -- "${OPTS}"

# Parsing arguments
while true; do
	case "$1" in
		-a | --alert-enable ) local -r _alert_enable=true; shift;;
		-b | --base-plage-ip ) local -r _base_plage_ip="${2}"; shift 2;;
		-c | --dns-address2 ) local -r _dns_address2="${2}"; shift 2;;
		-d | --dns-address1 ) local -r _dns_address1="${2}"; shift 2;;
		-e | --test-alert-email ) local -r _test_alert_email=true; shift;;
		-f | --alert-disable ) local -r _alert_disable=true; shift;;
		-h | --help ) usage; shift;;
		-i | --interval-ip ) local num_begin
							 local num_end
							 gestion_interval_ip "${2}" num_begin num_end
							 # Using readonly variables is better
							 local -r _num_begin="${num_begin}"
							 local -r _num_end="${num_end}"
		   					 shift 2;;
		-j | --disable-email-alert1 ) local -r _disable_email_alert1=true; shift;; 
		-k | --disable-email-alert2 ) local -r _disable_email_alert2=true; shift;; 
		-l | --disable-email-alert3 ) local -r _disable_email_alert3=true; shift;; 
		-m | --gw-address ) local -r _gw_address="${2}"; shift 2;;
		-n | --ntp-server-address ) local -r _ntp_server_address="${2}"; shift 2;;
		-o | --web-server-time-out ) local -r _web_server_time_out="${2}"; shift 2;;
		-p | --idrac-password ) gestion_mdp "${2}"; shift 2;;
		-q | --set-prefix-racname ) local -r _prefix_racname="${2}"; shift 2;;
		-r | --set-racname ) local -r _racname="${2}"; shift 2;;
		-s | --smtp-address )  local -r _smtp_address="${2}"; shift 2;;
		-t | --timezone ) local -r _timezone="${2}";  shift 2;;
		-u | --idrac-user ) local -r _idrac_user="${2}"; shift 2;;
		-v | --dns-domain-name ) local -r _dns_domain_name="${2}"; shift 2;;
		-w | --webserver-title-bar ) local -r _web_server_title_bar=true; shift ;;
		-x | --email-alert1 ) local -r _email_alert1="${2}"; shift 2;;
		-y | --email-alert2 ) local -r _email_alert2="${2}"; shift 2;;
		-z | --email-alert3 ) local -r _email_alert3="${2}"; shift 2;;
		--get-alert-enable ) local -r _get_alert_enable=true; shift;;
		--get-dns-address2 ) local -r _get_dns_address2=true; shift;;
		--get-dns-address1 ) local -r _get_dns_address1=true; shift;;
		-g | --getractime ) local -r _getractime=true; shift;;
		--get-gw-address ) local -r _get_gw_address=true; shift;;
		--get-ntp-server-address ) local -r _get_ntp_server_address=true; shift;;
		--get-web-server-time-out ) local -r _get_web_server_time_out=true; shift;;
		--get-racname ) local -r _get_racname=true; shift;;
		--get-smtp-address ) local -r _get_smtp_address=true; shift;;
		--get-timezone ) local -r _get_timezone=true; shift;;
		--get-dns-domain-name ) local -r _get_dns_domain_name=true; shift;;
		--get-email-alert1 ) local -r _get_email_alert1=true; shift;;
		--get-email-alert2 ) local -r _get_email_alert2=true; shift;;
		--get-email-alert3 ) local -r _get_email_alert3=true; shift;;
		--LCD-display-racname ) local -r _lcd_display_racname=true; shift;;
		--graceshutdown ) local -r _graceshutdown=true; shift;;
		--hardreset ) local -r _hardreset=true; shift;;
		--powercycle ) local -r _powercycle=true; shift;;
		--powerdown ) local -r _powerdown=true; shift;;
		--powerup ) local -r _powerup=true; shift;;
		--powerstatus ) local -r _powerstatus=true; shift;;
		-- ) shift; break ;;
		* ) break ;;
	esac
done

# Check if argument are compatible and well informed
if [ ! -z "${_racname}" ] && [ ! -z "${_prefix_racname}" ]; then
	echo
	echo "The options --set-prefix-racname and --set-racname can't be used together"
	echo
	exit 1
fi	

if [ -z "${_racname}" ] && [ -z "${_prefix_racname}" ] && [ ! -z "${_lcd_display_racname}" ]; then
	echo
	echo "Option --LCD-display-racname need to be used with --set-racname or --set-prefix-racname"
	echo
	exit 1
fi	

if [ ! -z "${_alert_enable}" ] && [ ! -z "${_alert_disable}" ]; then
	echo
	echo "The options --alert-enable and --alert-disable can't be used together"
	echo
	exit 1
fi	

if { [ "${_racname}" == "" ] && [ "${_prefix_racname}" == "" ]; } && [ "${_web_server_title_bar}" != "" ]; then
	echo
	echo "You have to use option --web-server-title-bar with --racname or --set-prefix-racname"
	echo
	exit 1
fi	

## Check if maximum one of this variables are set
local count=0
for flag in "${_graceshutdown}" "${_hardreset}" "${_powercycle}" "${_powerdown}" "${_powerup}" "${_powerstatus}"
do
	if [ "${flag}" == "true" ]; then
		count=$(( "${count}" + 1 ))
	fi
done
if [ "${count}" -gt 1 ]; then
	echo
	echo "The options --graceshutdown, --hardreset, --powercycle, --powerdown, --powerup and --powerstatus can't be used together"
	echo
	exit 1
fi	
##

if [ -z "${_base_plage_ip}" ];then
	echo "Missing base ip (i.e.: -b 192.168.254.)"
    usage
fi

if [ -z "${_num_begin}" ];then
	echo "Missing interval ip (i.e.: -i 16 or -i 10-20)"
    usage
fi

if [ -z "${_password}" ];then
    read -r -s -p "Enter your idrac password for the affected machines:" _password
    echo
fi

if [ -z "${_idrac_user}" ];then
    read -r -s -p "Enter your idrac admin login for the affected machines:" _idrac_user
    echo
fi
#

local _num
for _num in $(seq "${_num_begin}" "${_num_end}")
do
	echo
	echo "---------------------------------------------------------------"
	echo "Configuration or server action of ""${_base_plage_ip}${_num}"""
	echo "---------------------------------------------------------------"

	# Define _racname_to_use var for this loop
	if [ ! -z "${_racname}" ]; then 
		local _racname_to_use="${_racname}"
	elif [ ! -z "${_prefix_racname}" ]; then
		local _racname_to_use="${_prefix_racname}""${_num}"
	fi
	
	# Define prefix racadm command
	local _ssh_racadm_cmd=(sshpass -p "${_password}" ssh -o "StrictHostKeyChecking=no" "${_idrac_user}"@"${_base_plage_ip}""${_num}" racadm)

	[ ! -z "${_alert_enable}" ] && \
		echo && echo "Set status of alert to enable" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.IPMILan.AlertEnable 1 && \
		echo "Enable all email alerts, ignore error message" && \
		"${_ssh_racadm_cmd[@]}" eventfilters set -c idrac.alert.all -a none -n email
	
	[ ! -z "${_get_alert_enable}" ] && \
		echo && echo "Get status of alert" && \
	   	"${_ssh_racadm_cmd[@]}" get iDRAC.IPMILan.AlertEnable
	
	[ ! -z "${_dns_address2}" ] && \
	   echo && echo "Set DNS address2" && \
	   "${_ssh_racadm_cmd[@]}" set iDRAC.IPv4.DNS2 "${_dns_address2}"
	
	[ ! -z "${_get_dns_address2}" ] && \
	   echo && echo "Get DNS address2" && \
	   "${_ssh_racadm_cmd[@]}" get iDRAC.IPv4.DNS2 

	[ ! -z "${_dns_address1}" ] && \
		echo && echo "Set DNS1 address" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.IPv4.DNS1 "${_dns_address1}"
	
	[ ! -z "${_get_dns_address1}" ] && \
	   echo && echo "Get DNS address1" && \
	   "${_ssh_racadm_cmd[@]}" get iDRAC.IPv4.DNS1 
	
	[ ! -z "${_alert_disable}" ] && \
		echo && echo "Set status of alert to disable" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.IPMILan.AlertEnable 0
	
	[ ! -z "${_getractime}" ] && \
		echo && echo "Get ractime" && \
	   	"${_ssh_racadm_cmd[@]}" getractime 
	
	[ ! -z "${_disable_email_alert1}" ] && \
		echo && echo "Disable email1" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.EmailAlert.1.Enable Disabled
	
	[ ! -z "${_disable_email_alert2}" ] && \
		echo && echo "Disable email2" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.EmailAlert.2.Enable Disabled
	
	[ ! -z "${_disable_email_alert3}" ] && \
		echo && echo "Disable email3" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.EmailAlert.3.Enable Disabled 

	[ ! -z "${_ntp_server_address}" ] && \
		echo && echo "Set NTP server address and enable" &&  \
		"${_ssh_racadm_cmd[@]}" set iDRAC.NTPConfigGroup.NTP1 "${_ntp_server_address}" && \
		"${_ssh_racadm_cmd[@]}" set idrac.NTPConfigGroup.NTPEnable Enabled
	
	[ ! -z "${_get_ntp_server_address}" ] && \
		echo && echo "Get NTP server address and if enable" &&  \
		"${_ssh_racadm_cmd[@]}" get iDRAC.NTPConfigGroup.NTP1 && \
		"${_ssh_racadm_cmd[@]}" get idrac.NTPConfigGroup.NTPEnable

	[ ! -z "${_gw_address}" ] && \
		echo && echo "Set gateway adress" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.IPv4.Gateway "${_gw_address}"
	
	[ ! -z "${_get_gw_address}" ] && \
		echo && echo "Get gateway adress" && \
	   	"${_ssh_racadm_cmd[@]}" get iDRAC.IPv4.Gateway
	
	[ ! -z "${_web_server_time_out}" ] && \
		echo && echo "Set web server time out" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.WebServer.Timeout "${_web_server_time_out}"
	
	[ ! -z "${_get_web_server_time_out}" ] && \
		echo && echo "Get web server time out" && \
	   	"${_ssh_racadm_cmd[@]}" get iDRAC.WebServer.Timeout
	
	[ ! -z "${_prefix_racname}" ] && \
		echo && echo "Set prefix racname" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.NIC.DNSRacName "${_prefix_racname}""${_num}"
	
	[ ! -z "${_racname}" ] && \
		echo && echo "Set racname" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.NIC.DNSRacName "${_racname}"
	
	[ ! -z "${_get_racname}" ] && \
		echo && echo "Get racname" && \
	   	"${_ssh_racadm_cmd[@]}" get iDRAC.NIC.DNSRacName
	
	[ ! -z "${_smtp_address}" ] && \
		echo && echo "Set SMTP address" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.RemoteHosts.SMTPServerIPADDRESS "${_smtp_address}"
	
	[ ! -z "${_get_smtp_address}" ] && \
		echo && echo "Get SMTP address" && \
	   	"${_ssh_racadm_cmd[@]}" get iDRAC.RemoteHosts.SMTPServerIPADDRESS
	
	[ ! -z "${_timezone}" ] && \
		echo && echo "Set Timezone" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.Time.Timezone "${_timezone}"
	
	[ ! -z "${_get_timezone}" ] && \
		echo && echo "Get Timezone" && \
	   	"${_ssh_racadm_cmd[@]}" get iDRAC.Time.Timezone
	
	[ ! -z "${_email_alert1}" ] && \
		echo && echo "Set email1 and enable" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.EmailAlert.1.Address "${_email_alert1}" && \
		"${_ssh_racadm_cmd[@]}" set iDRAC.EmailAlert.1.Enable Enabled
	
	[ ! -z "${_get_email_alert1}" ] && \
		echo && echo "Get email1 and if enable" && \
	   	"${_ssh_racadm_cmd[@]}" get iDRAC.EmailAlert.1.Address && \
		"${_ssh_racadm_cmd[@]}" get iDRAC.EmailAlert.1.Enable
	
	[ ! -z "${_email_alert2}" ] && \
		echo && echo "Set email2 and enable" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.EmailAlert.2.Address "${_email_alert2}" && \
		"${_ssh_racadm_cmd[@]}" set iDRAC.EmailAlert.2.Enable Enabled
	
	[ ! -z "${_get_email_alert2}" ] && \
		echo && echo "Get email2 and if enable" && \
	   	"${_ssh_racadm_cmd[@]}" get iDRAC.EmailAlert.2.Address && \
		"${_ssh_racadm_cmd[@]}" get iDRAC.EmailAlert.2.Enable
	
	[ ! -z "${_email_alert3}" ] && \
		echo && echo "Set email3 and enable" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.EmailAlert.3.Address "${_email_alert3}" && \
		"${_ssh_racadm_cmd[@]}" set iDRAC.EmailAlert.3.Enable Enabled
	
	[ ! -z "${_get_email_alert3}" ] && \
		echo && echo "Get email3 and if enable" && \
	   	"${_ssh_racadm_cmd[@]}" get iDRAC.EmailAlert.3.Address && \
		"${_ssh_racadm_cmd[@]}" get iDRAC.EmailAlert.3.Enable
	
	[ ! -z "${_dns_domain_name}" ] && \
		echo && echo "Set DNS Domain Name" && \
	   	"${_ssh_racadm_cmd[@]}" set iDRAC.NIC.DNSDomainName "${_dns_domain_name}"
	
	[ ! -z "${_get_dns_domain_name}" ] && \
		echo && echo "Get DNS Domain Name" && \
	   	"${_ssh_racadm_cmd[@]}" get iDRAC.NIC.DNSDomainName
	
	[ ! -z "${_lcd_display_racname}" ] && [ ! -z "${_racname_to_use}" ] && \
		echo && echo "Set the LCD display to racname ""${_racname_to_use}""" && \
	   	"${_ssh_racadm_cmd[@]}" set System.LCD.Configuration 0 && \
		"${_ssh_racadm_cmd[@]}" set System.LCD.LCDUserString "${_racname_to_use}"
	
	[ ! -z "${_web_server_title_bar}" ] && [ ! -z "${_racname_to_use}" ] && \
		echo && echo "Set web server title bar to ""${_racname_to_use}""" && \
	   	"${_ssh_racadm_cmd[@]}" set iDrac.WebServer.TitleBarOptionCustom "${_racname_to_use}"
	
	# This command is placed here so that it can benefit from any modifications above
	[ ! -z "${_test_alert_email}" ] && \
		echo && echo "Test alert email" && \
	   	"${_ssh_racadm_cmd[@]}" testemail -i 1

	# Server action
	[ ! -z "${_graceshutdown}" ] && \
		echo && echo "Grace shutdown" && \
		"${_ssh_racadm_cmd[@]}" serveraction graceshutdown	
	
	[ ! -z "${_hardreset}" ] && \
		echo && echo "Hard reset" && \
		"${_ssh_racadm_cmd[@]}" serveraction hardreset	
	
	[ ! -z "${_powercycle}" ] && \
		echo && echo "Power cycle" && \
		"${_ssh_racadm_cmd[@]}" serveraction powercycle
	
	[ ! -z "${_powerdown}" ] && \
		echo && echo "Power down" && \
		"${_ssh_racadm_cmd[@]}" serveraction powerdown
	
	[ ! -z "${_powerup}" ] && \
		echo && echo "Power up" && \
		"${_ssh_racadm_cmd[@]}" serveraction powerup
	
	[ ! -z "${_powerstatus}" ] && \
		echo && echo "Power status" && \
		"${_ssh_racadm_cmd[@]}" serveraction powerstatus
done
echo
}

# Script execution
main "${@}"
exit 0

