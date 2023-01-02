#!/bin/bash
#
# ===========================================
# PROJECT: MultiVPN Server
# ===========================================
# Author: Gabriel Hinz
# Date: 12-30-2021
# Version: 1.0
# -------------------------------------------
# Desc: Project to create and manipulate
# multiple simultaneous vpn servers.
#
# To know more about this project, see in 
# the github project page.
#
# License: MIT License
# ------------------------------------------

source config

# ----------------------------------
# Functions
# ----------------------------------
usage() {
	echo -e "Usage: $0 [OPTIONS]" \
	"\nInfo:" \
	"\n -h,\t--help\t\tShow help message" \
	"\n -l,\t--list\t\tLists all created vpns" \
	"\nIntegrations:" \
	"\n --init\t\t\tStarts creating a new vpn" \
	"\n --start [vpn|all]\tStart the vpn, can be passed the name of the vpn or 'all'" \
	"\n --stop  [vpn|all]\tStop the vpn, can be passed the name of the vpn or 'all'" \
	"\n --enable [vpn]\t\tEnable to turn on vpn on reboot" \
	"\n --forward [vpn]\tCreate or remove a forward rule for a vpn" 
	exit 1;
}

check_dependencies() {
	package_install() {
		os=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
		if grep -qs "ubuntu" /etc/os-release; then
			apt-get update
			apt-get install $1 -y 2>/dev/null
		elif grep -qs "centos" /etc/os-release; then
			yum update
			yum install epel-release -y
			yum install $1 -y 2>/dev/null
		else
			cecho red "Can't install $1!"
			exit
		fi
	}
	echo -e "\nChecking dependencies.."
	if ! which openvpn &>/dev/null; then
		read -rep $'\nOpenVPN not installed, continue to install? ' install
		[[ "$install" =~ ^[yY]$ ]] || exit 1
		cecho yellow "Installing OpenVPN.."
		package_install openvpn
		if ! which openvpn &>/dev/null; then
			cecho red "Try to install in another way!"
			exit 1
		fi
	else
		mkdir -p /etc/openvpn/multivpn
	fi
	if ! which wget &>/dev/null; then
		read -rep $'\nwget not installed, continue to install? ' install
		[[ "$install" =~ ^[yY]$ ]] || exit 1
		cecho yellow "Installing wget.."
		package_install wget
		if ! which wget &>/dev/null; then
			cecho red "Try to install in another way!"
		exit 1
	fi
	fi
	if [ ! -f $SERVICE_ROOT/multivpn.service ]; then
		cp $SERVICE_NAME $SERVICE_ROOT/
	fi
	iptables_file="$ROOT_VPN/multivpn/rc.iptables"
	if [ ! -f $iptables_file ]; then
		mkdir -p $ROOT_VPN/multivpn
		cat $RULES_MAIN > $iptables_file
	fi
}

start_vpn() {
	vpn_targ=$1
	vpn_home=$ROOT_VPN/$vpn_targ
	if ps -ef | grep "[o]penvpn --cd $vpn_home" &>/dev/null; then
		if [ -e $vpn_home/vpn-server.lock ]; then
			cecho green "[Running]"
			return 1
		else
			touch $vpn_home/vpn-server.lock
			cecho green "[Locked]"
			return 1
		fi
	else
		if [ -e $vpn_home/vpn-server.lock ]; then
			rm -f $vpn_home/vpn-server.lock
		fi
	fi
	/usr/sbin/openvpn --cd $vpn_home --script-security 2 --daemon \
		--config $vpn_home/openvpn.conf &>/dev/null \
		 && echo_success || echo_failed 
	[[ $? -eq 0 ]] && touch $vpn_home/vpn-server.lock
	return $?
}

stop_vpn() {
	vpn_targ=$1
	vpn_home=$ROOT_VPN/$vpn_targ
	vpn_pid=$(ps -ef | grep "[o]penvpn --cd $vpn_home" | awk '{ print $2 }')
	if [ ! -z $vpn_pid ]; then
		kill $vpn_pid &>/dev/null && echo_success || echo_failed 
	else
		cecho red "[Not Running]"
	fi
	[[ $? -eq 0 ]] && rm -f $vpn_home/vpn-server\.lock
	return $?
}

list_vpn() {
	for vpn in $_ALL; do
		if ps -ef | grep "[o]penvpn --cd $ROOT_VPN/$vpn" &>/dev/null; then
			log_file=$(awk '/status/ {print $2}' $ROOT_VPN/$vpn/openvpn.conf)
			connections=$(cat $log_file | egrep -o $VIP_REGEX | wc -l)
			echo -e "VPN: $vpn"
			echo -e "STATUS: $(cecho green 'Running')"
			echo -e "CONNECTIONS: $connections"
			echo -e "---------------------"
		else
			echo -e "VPN: $vpn"
			echo -e "STATUS: $(cecho red 'Stopped')"
			echo -e "CONNECTIONS: 0"
			echo -e "---------------------"
		fi
	done
	return $?
}

# ----------------------------------
# Start
# ----------------------------------
if [ $EUID -ne 0 ]; then
       	cecho red "Error: run with root user"
	exit
fi
$ROOT/resources/header && check_dependencies

_ALL=$(find $ROOT_VPN/ -maxdepth 1 -type d | egrep -o $VPN_REGEX)
_OPTIONS=$(getopt -o lh --long help,enable:,list,start:,stop:,init,forward: -- "$@")

eval set -- "$_OPTIONS"

while true; do
	case "$1" in
		--start )
			[[ "${2}" =~ $VPN_REGEX || "${2}" = 'all' ]] && arg=${2} || usage
			cecho yellow "\nSTARTING:"
			if [ $arg = 'all' ]; then
				for vpn in $_ALL; do
					printf '%-25s' "Starting $vpn"
					start_vpn $vpn
				done
			else
				printf '%-25s' "Starting $arg"
				if [ -f "$ROOT_VPN/$arg/openvpn.conf" ]; then 
					start_vpn $arg
				else
					cecho red "[Not found]"
					exit 1
				fi
			fi
			break ;;
		--stop )
			[[ "${2}" =~ $VPN_REGEX || "${2}" = 'all' ]] && arg=${2} || usage
			cecho yellow "\nSTOPPING:"
			if [ $arg = 'all' ]; then
				for vpn in $_ALL; do
					printf '%-25s' "Stopping $vpn"
					stop_vpn $vpn
				done
			else
				if [ -f "$ROOT_VPN/$arg/openvpn.conf" ]; then 
					printf '%-25s' "Stopping $arg"
					stop_vpn $arg
				else
					printf '%-25s' "Stopping $arg"
					cecho red "[Not found]"
					exit 1
				fi
			fi
			break ;;
		--enable )
			[[ "${2}" =~ $VPN_REGEX || "${2}" = 'all' ]] && arg=${2} || usage
			cecho yellow "\nENABLING:"
			if [ ! -f $RULES_AUTOSTART ]; then
				cp $RULES_ATUOSTART $ROOT_VPN/multivpn/
			fi	
			if [ $arg = 'all' ]; then
				for vpn in $_ALL; do
					printf '%-22s' "Enabling $vpn"
					if ! grep -q $vpn $ROOT_VPN/multivpn/.enabled 2>/dev/null; then
						echo $vpn >> $ROOT_VPN/multivpn/.enabled
					fi
					cecho green "[Enabled]"
				done
			else
				printf '%-22s' "Enabling $arg"
				if ! grep -q $arg $ROOT_VPN/multivpn/.enabled; then
					echo $arg >> $ROOT_VPN/multivpn/.enabled
				fi
				cecho green "[Enabled]"
			fi
			break ;;
		--forward )
			[[ "${2}" =~ $VPN_REGEX ]] && arg=${2} || usage
			cecho yellow "\nVPN FORWARD CONFIG:"
			read -p "Add or Remove [a/R]: " config_type
			if [[ $config_type =~ ^[aA] ]]; then
				[[ -f $ROOT_VPN/$arg/.vars ]] && source $ROOT_VPN/$arg/.vars || {
					cecho red "Can't find $arg"
					exit 0
				}
				read -p "Allow $arg FORWARD (ex: 192.168.1.0/24): " forward_range
				rule="iptables -A FORWARD -i $interface -s $network/24 -d $forward_range -j ACCEPT"
				echo $rule >> $ROOT_VPN/$arg/rules/iptables && {
					iptables -D FORWARD -j DROP && $rule
					iptables -A FORWARD -j DROP
				}
			elif [[ $config_type =~ ^[rR] ]]; then
				[[ -f $ROOT_VPN/$arg/.vars ]] && source $ROOT_VPN/$arg/.vars || {
					cecho red "Can't find $arg"
					exit 0
				}
				echo -e "\nRules:"
				[[ $(cat "$ROOT_VPN/$arg/rules/iptables" | wc -l) == 0 ]] && {
					echo -e "There are no rules to remove."
					exit 1
				}
				IFS=$'\n'
				for line in $(cat "$ROOT_VPN/$arg/rules/iptables"); do
					counter=$((counter+1))
					echo "[$counter]" "$line"
				done		
				read -rep $'\nSelect rule number to remove: ' rule_line
				rule=$(sed -n ${rule_line}p $ROOT_VPN/$arg/rules/iptables)
				if test $rule; then
					exclude_rule=$(echo $rule | sed 's/\-A/\-D/')
					bash -c $exclude_rule
				fi
				sed -i "${rule_line}d" $ROOT_VPN/$arg/rules/iptables 
			fi
			break ;;
		--init )
			bash createvpn
			break ;;
		--list | -l ) 
			cecho yellow "\nVPN DETAILS:"
			echo -e "---------------------"
			list_vpn
			break ;;
		--help | -h ) usage ;;
		-- ) echo; usage ;;
	esac
done
