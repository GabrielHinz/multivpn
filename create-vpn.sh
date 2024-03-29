#!/bin/bash
#
# ===========================================
# PROJECT: MultiVPN Server
# ===========================================
# Author: Gabriel Hinz
# Created: 12-30-2021
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

# ---------------------------------------------
# GET EASY-RSA
# ---------------------------------------------
archive_file="EasyRSA-2.2.2"
if [ ! -d  'easy-rsa' ]; then
	wget -q https://github.com/OpenVPN/easy-rsa/releases/download/2.2.2/$archive_file.tgz && {
		tar -xf $archive_file.tgz
		rm -f $archive_file.tgz
		mv $archive_file easy-rsa
	} || cecho red "Can't install easy-rsa 2.2.2"
fi

# ---------------------------------------------
# SELF-SIGNED INFORMATIONS
# ---------------------------------------------
if [ "${GEN_VARS}:no" = 'yes'  ]; then
	while [ "$VAR_ACCEPT" != 'yes' ]; do
		cecho yellow "\nSELF-SIGNED CERTIFICATE:"
		read -p "Country: " VAR_COUNTRY
		read -p "Province: " VAR_PROVINCE
		read -p "City: " VAR_CITY
		read -p "Organization: " VAR_ORG
		read -p "Unit: " VAR_OU
		read -p "Email: " VAR_EMAIL

		read -p "Confirm [yes/no]: " VAR_ACCEPT
	done
else
	cecho yellow "\nLOADING FROM CONFIG FILE:"
	echo -e "Country: $VAR_COUNTRY"
	echo -e "Province: $VAR_PROVINCE"
	echo -e "City: $VAR_CITY"
	echo -e "Organization: $VAR_ORG"
	echo -e "Unit: $VAR_OU"
	echo -e "Email: $VAR_EMAIL\n"
	
	read -p "CONFIRM [yes/no]: " VAR_ACCEPT

	[[ "${VAR_ACCEPT,,}" != 'yes' ]] && echo "Exiting.." && exit
fi

sed -i "s/KEY_COUNTRY=.*/KEY_COUNTRY=\"$VAR_COUNTRY\"/" easy-rsa/vars
sed -i "s/KEY_PROVINCE=.*/KEY_PROVINCE=\"$VAR_PROVINCE\"/" easy-rsa/vars
sed -i "s/KEY_CITY=.*/KEY_CITY=\"$VAR_CITY\"/" easy-rsa/vars
sed -i "s/KEY_ORG=.*/KEY_ORG=\"$VAR_ORG\"/" easy-rsa/vars
sed -i "s/KEY_OU=.*/KEY_OU=\"$VAR_OU\"/" easy-rsa/vars
sed -i "s/KEY_EMAIL=.*/KEY_EMAIL=\"$VAR_EMAIL\"/" easy-rsa/vars

cecho yellow "\nVPN SERVER CONFIG:"

[[ -z $VPN_CLIENT ]] && read -p "Name: " VPN_CLIENT
[[ -z $NUM_CLIENT ]] && read -p "Number (1-254): " NUM_CLIENT
# read -p "User/Pass Authentication? [y/N] " VPN_AUTH

while ((NUM_CLIENT < 1 || NUM_CLIENT > 254)); do
	echo "Select a valid number!"
	read -p "Number (1-254): " NUM_CLIENT
done

if ls $ROOT_VPN | grep -e "^$(printf '%02d' $NUM_CLIENT)-*" &>/dev/null; then
	cecho red "\nNumber already registered!"
	exit
fi

# ---------------------------------------------
# RSA GENERATNG
# ---------------------------------------------
CA_DIR="$ROOT/easy-rsa"
cd $CA_DIR && source ./vars &>/dev/null

if [ ! -f $CA_DIR/openssl.cnf ]; then
	ln -s 'openssl-1.0.0.cnf' 'openssl.cnf'
fi

cecho yellow "\nCREATING RSA FILES:"
printf '%-30s' "Generating Diffie-Hellman" && {
	./clean-all &>/dev/null
	./build-dh &>/dev/null
} && echo_success || echo_failed

printf '%-30s' "Generating CA" && {
	./pkitool --initca &>/dev/null
} && echo_success || echo_failed

printf '%-30s' "Generating TLS" && {
	openvpn --genkey --secret keys/ta.key &>/dev/null
} && echo_success || echo_failed

printf '%-30s' "Generating Server Cert" && {
	./pkitool --server server &>/dev/null
} && echo_success || echo_failed

printf '%-30s' "Generating Client Cert" && {
	./pkitool $VPN_CLIENT &>/dev/null
} && echo_success || echo_failed

# ---------------------------------------------
# CLIENT VPN DIR
# ---------------------------------------------
CLIENT_ROOT="$ROOT/vpn/$VPN_CLIENT"

cecho yellow "\nCREATING VPN ROOT:"
printf '%-30s' "Creating Dir" && {
	mkdir -p $CLIENT_ROOT/{client,cert,rules}
} && echo_success || echo_failed
printf '%-30s' "Moving RSA Files" && {
	mv $CA_DIR/keys/dh2048.pem $CLIENT_ROOT/;
	mv $CA_DIR/keys/ca.* $CLIENT_ROOT/ 
	mv $CA_DIR/keys/server.crt $CLIENT_ROOT/
	mv $CA_DIR/keys/server.key $CLIENT_ROOT/
	mv $CA_DIR/keys/ta.key $CLIENT_ROOT/
	mv $CA_DIR/keys/$VPN_CLIENT* $CLIENT_ROOT/cert
} &>/dev/null && echo_success || echo_failed

# ---------------------------------------------
# VPN CREATION - Start
# ---------------------------------------------
FORMATED_NUM=$(printf "%02d" $NUM_CLIENT)
PORT=$((11900 + $NUM_CLIENT))
TEMP=$ROOT/vpn/vpn-$VPN_CLIENT\.tmp

cecho yellow "\nGENERATE VPN FILES:"

# ---------------------------------------------
# VPN CREATION - Client
# ---------------------------------------------
printf '%-30s' "Creating Client File" && {
	cat $SKEL_CLIENT | base64 -d > $TEMP
	sed -i "s/{{CONNECT}}/$CONNECT_SERVER/" $TEMP
	sed -i "s/{{CLIENT}}/$VPN_CLIENT/" $TEMP
	sed -i "s/{{NUMBER}}/$NUM_CLIENT/" $TEMP
	sed -i "s/{{PORT}}/$PORT/" $TEMP
	 [[ "$VPN_AUTH" =~ ^[yY]$ ]] && \
		echo "auth-user-pass" >> $TEMP
	echo "<ca>" >> $TEMP
	cat $CLIENT_ROOT/ca.crt >> $TEMP
	echo "</ca>" >> $TEMP
	echo "<cert>" >> $TEMP
	cat $CLIENT_ROOT/cert/$VPN_CLIENT.crt >> $TEMP
	echo "</cert>" >> $TEMP
	echo "<key>" >> $TEMP
	cat $CLIENT_ROOT/cert/$VPN_CLIENT.key >> $TEMP
	echo "</key>" >> $TEMP
	echo "<tls-auth>" >> $TEMP
	cat $CLIENT_ROOT/ta.key >> $TEMP
	echo "</tls-auth>" >> $TEMP
	mv $TEMP $CLIENT_ROOT/client/$FORMATED_NUM\-$VPN_CLIENT.ovpn 
} &>/dev/null && echo_success || echo_failed

# ---------------------------------------------
# VPN CREATION - Server
# ---------------------------------------------
printf '%-30s' "Creating Server File" && {
	cat $SKEL_SERVER | base64 -d > $TEMP
	sed -i "s/{{CLIENT}}/$VPN_CLIENT/" $TEMP
	sed -i "s/{{NUMBER}}/$NUM_CLIENT/" $TEMP
	sed -i "s/{{PORT}}/$PORT/" $TEMP
	sed -i "s/{{TUN}}/tun$NUM_CLIENT/" $TEMP
	sed -i "s/{{NETWORK}}/$IPV4_FOCT\.$IPV4_SOCT\.$NUM_CLIENT\.0/" $TEMP
	sed -i "s/{{ROUTE}}/$VPN_ROUTE/" $TEMP
	sed -i "s/{{MASK}}/$VPN_MASK/" $TEMP
	sed -i "s/{{VPN_DNS}}/$VPN_DNS/" $TEMP
	[[ "$VPN_AUTH" =~ ^[yY]$ ]] && \
		 echo "auth-user-pass-verify auth.py via-env" >> $TEMP
	mv $TEMP $CLIENT_ROOT/openvpn.conf
} &>/dev/null && echo_success || echo_failed

printf '%-30s' "Creating Vars" && {
	cat $SKEL_VARS | base64 -d > $TEMP
	sed -i "s/{{CLIENT}}/$VPN_CLIENT/g" $TEMP
	sed -i "s/{{NUMBER}}/$NUM_CLIENT/g" $TEMP
	sed -i "s/{{PORT}}/$PORT/" $TEMP
	sed -i "s/{{TUN}}/tun$NUM_CLIENT/" $TEMP
	sed -i "s/{{NETWORK}}/$IPV4_FOCT\.$IPV4_SOCT\.$NUM_CLIENT\.0/" $TEMP
	[[ "$VPN_AUTH" =~ ^[yY]$ ]] && VPN_SECURITY="3" || VPN_SECURITY="2"
	sed -i "s/{{SECURITY}}/$VPN_SECURITY/" $TEMP
	mv $TEMP $CLIENT_ROOT/.vars
} &>/dev/null && echo_success || echo_failed

printf '%-30s' "Creating Rules" && {
	cat $RULES_CUSTOM > $TEMP
	sed -i '/^#/d' $TEMP
	sed -i "s/{{PORT}}/$PORT/g" $TEMP
	sed -i "s/{{TUN}}/tun$NUM_CLIENT/g" $TEMP
	 sed -i "s/{{NETWORK}}/$IPV4_FOCT\.$IPV4_SOCT\.$NUM_CLIENT\.0/g" $TEMP
	sed -i "s/{{DNS}}/$VPN_DNS/g" $TEMP
	mv $TEMP $CLIENT_ROOT/rules/iptables
	iptables -C FORWARD -j DROP 2>/dev/null && {
		iptables -D FORWARD -j DROP
		bash $CLIENT_ROOT/rules/iptables
		iptables -A FORWARD -j DROP
	} || bash $CLIENT_ROOT/rules/iptables
} &>/dev/null && echo_success || echo_failed

# ---------------------------------------------
# FINISHING
# ---------------------------------------------
[[ $errors = 'true' ]] && {
	cecho red "\nErrors were found in the operation, exiting.."
	exit 1
}

[[ "$VPN_AUTH" =~ ^[yY]$ ]] && {
	cp $ROOT/auth/resources/auth.py $CLIENT_ROOT
	chmod +x $CLIENT_ROOT/auth.py
}

if mv $ROOT/vpn/$VPN_CLIENT $ROOT_VPN/$FORMATED_NUM\-$VPN_CLIENT; then
	cecho green "\nVPN $FORMATED_NUM-$VPN_CLIENT Created!"
	$ROOT/easy-rsa/clean-all
fi

cecho yellow "\nMANAGE VPN:"
echo -e "list: sudo ./manage.sh --list "
echo -e "start: sudo ./manage.sh --start $VPN_CLIENT"
echo -e "stop: sudo ./manage.sh --stop $VPN_CLIENT"
