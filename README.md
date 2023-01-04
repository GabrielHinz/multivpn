# MultiVPN Server Generator
Creates and configure multiple VPN servers with specific forwarding rules.

## Getting Started
Using this openvpn based tool you can quickly create multiple vpn services and configure forwarding of your planned routes.

### Prerequisites
Requirements for running this script. To avoid runtime problems, make sure the requirements are installed, otherwise the tool will try to install on first run (only on ubuntu and centos).
- openvpn
- wget

### Recomendations
Run this program on a linux server CentOS or Ubuntu.
* Tested on a Centos7 server.
* Tested on a Ubuntu 18.04 server.

### Installing
To run this project on your server, first clone the repository

    git clone https://github.com/GabrielHinz/multivpn.git
    
Then access the created directory
 
    cd multivpn
    
### Configuration 
On config file, define the your network and company settings. You can leave most of it as default, and change the fields using your favorite editor:

    vim config

#### Network settings
* CONNECT_SERVER: Your server's IP or DNS record
* VPN_DNS: The DNS that will be used in your VPN
* VPN_ROUTE: The route of your network.
* VPN_MASK: The mask used by your route.

#### Self-signed cert settings
* VAR_COUNTRY: 2 letter code of yout country
* VAR_PROVINCE: Full name of your province
* VAR_CITY: Full name of your city
* VAR_ORG: The name of your organization/company
* VAR_OU: Your organizational unit name (eg, section)
* VAR_EMAIL: Email address

## Creating the first VPN
To start using multivpn, use the root user of your server
    
    sudo su
    
In the multivpn directory, starts a new VPN executing:

    manage.sh --init
    
Confirm your self-signed cert data and continue. 

Then, create a name to your VPN, and select a unique number (1-254).

Now, wait while VPN is created. If everything went well, you will receive a green message that the VPN was successfully created,
your new VPN files are stored in /etc/openvpn/`number-name`

Activate your newly created VPN, using:
    
    manage.sh --start all
    
Get the `client.ovpn` file to connect in this VPN server

    cat /etc/openvpn/01-test/client/01-test.ovpn  # Assuming the VPN name was test and the number was 1

Before testing, activate the multivpn service that will create the iptables rules for connecting and forwarding.
    
    systemctl enable multivpn
    systemctl start multivpn
    
Now, use a connector and the `client.ovpn` generated file and use to connect in the VPN:
 - [OpenVPN Connector Windows](https://openvpn.net/client-connect-vpn-for-windows/) - Connector used to access VPN
 - [OpenVPN Connector MacOS](https://openvpn.net/client-connect-vpn-for-mac-os/) - Connector used to access VPN
 - [OpenVPN for Linux](https://openvpn.net/vpn-server-resources/connecting-to-access-server-with-linux/) - How to connect using Linux
 
 You now have an active VPN, and you can repeat this process to create new ones.
 
 ## Forward Rules for VPN
You can enable forward for your VPNs to be able to connect to other servers.

First, go to multivpn directory and run:

    manage.sh --forward 01-test   # Assuming the VPN name was test and number 1
    
Now you will be asked if you want to add or remove, let's keep adding a new rule.

In this step, you must enter the ip range that you would like to enable for this vpn's clients.
As an example, we will enable the ip 192.168.1.5 passing as response: 192.168.1.5/32

Done! Now the client can connect to 192.168.1.5 when is connected to VPN 01-test.

## Nice Commands

List All VPNs 

    manage.sh --list

Stop All VPNs

    manage.sh --stop all

Start All VPNs

    manage.sh --start all
    
To enable a VPN to start on reboot

    manage.sh --enable number-name
    
## Contributing
This project is open for contributions and improvements, identify the processes and send a pull request

## Authors
- **Gabriel Hinz** - *DevOps Eng.* -
    [About](https://github.com/GabrielHinz)
    
## License
This project is licensed under the MIT License (LICENSE.md)
