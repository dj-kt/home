# prep

```bash
sudo apt install dnsmasq ufw
```

### enable forwarding

`sudo vim /etc/sysctl.conf`

```
# uncomment this
net.ipv4.ip_forward=1
```

`sudo vim /etc/default/ufw`

```
IPV6=no
DEFAULT_FORWARD_POLICY="ACCEPT"
```

# setup network

### single interface network setup

`sudo vim /etc/network/interfaces.d/router`

```
# auto eth0 # uncomment to pause boot until connected
allow-hotplug eth0
iface eth0 inet dhcp
        # hwaddress ether aa:bb:cc:dd:ee:ff


# create a single lan network
# auto eth1
allow-hotplug eth1
iface eth1 inet static
       address 192.168.1.1
       network 192.168.1.0
       netmask 255.255.255.0
       broadcast 192.168.1.255
```

### multiple interface setup with a bridge

`sudo apt install bridge-utils`

```
allow-hotplug eth1
allow-hotplug wlan0
auto br0
iface br0 inet static
       address 192.168.1.1
       network 192.168.1.0
       netmask 255.255.255.0
       broadcast 192.168.1.255
       bridge-ports eth1 wlan0
```

### dhcpcd bridge

`sudo vim  /etc/network/interfaces`

```
iface eth1 inet manual
iface wlan0 inet manual

auto br0
iface br0 inet manual
  bridge_ports eth1 wlan0
```

`sudo vim /etc/dhcpcd.conf`

```
denyinterfaces eth1 wlan0
interface br0
    static ip_address=192.168.1.1/24
    static domain_name_servers=127.0.0.1 # 8.8.8.8 1.1.1.1
```

### netplan systems

`sudo vim /etc/netplan/01-abc.yaml`

#### network manager

```yaml
network:
  version: 2
  renderer: NetworkManager
```

#### single lan

```yaml
network:
    ethernets:
        eth0:
           dhcp4: true
        eth1:
            addresses:
            - 192.168.1.1/24
            dhcp4: false
            nameservers:
                addresses:
                - 1.1.1.1
                - 8.8.8.8
                - 8.8.4.4
                search: []
            optional: true
    version: 2
```

#### single wlan

```yaml
network:
    wifis:
      wlan0:
          access-points:
              ssidwasd:
                  password: xxxxxxxxxxxxxxxx
              ssidhjkl:
                  password: zzzzzzzzzzzzzzzz
          dhcp4: true
    ethernets:
        eth1:
            addresses:
            - 192.168.1.1/24
            dhcp4: false
            nameservers:
                addresses:
                - 1.1.1.1
                - 8.8.8.8
                - 8.8.4.4
                search: []
            optional: true
    version: 2
```

#### bridge lan

```yaml
network:
    ethernets:
        eth0:
           dhcp4: true
        eth1:
           dhcp4: false
           optional: true
        eth2:
           dhcp4: false
           optional: true
        wlan0:
           dhcp4: false
           optional: true
    bridges:
        br0:
            addresses:
            - 192.168.123.1/24
            dhcp4: false
            nameservers:
                addresses:
                - 1.1.1.1
                - 8.8.8.8
                - 8.8.4.4
                search: []
            interfaces:
                - eth1
                - eth2
                - wlan0
    version: 2

```

#### wake on lan

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      match:
        macaddress: aa:bb:cc:dd:ee:ff
      dhcp4: true
      wakeonlan: true
```

```bash
sudo netplan generate
sudo netplan apply
```

# setup server

`sudo vim /etc/dnsmasq.d/router.conf`

```conf
no-resolv
server=1.1.1.1

interface=br0
dhcp-range=192.168.1.100,192.168.1.250,72h

addn-hosts=/etc/hosts_custom
dhcp-host=00:11:22:33:44:55,192.168.1.123,static_host_name
```

### force static hosts only
```
dhcp-range=192.168.1.1,192.168.1.1,0m
```

### flush dnsmasq leases
```
sudo sh -c 'echo > /var/lib/misc/dnsmasq.leases'
```

# setup firewall

`sudo vim /etc/ufw/before.rules`

```
#
# rules.before
#
# Rules that should be run before the ufw command line added rules. Custom
# rules should be added to one of these chains:
#   ufw-before-input
#   ufw-before-output
#   ufw-before-forward
#
# RULES
*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0] 
-F
# FORWARD PORTS
# -A PREROUTING -i eth0 -p tcp --dport 27015 -j DNAT --to-destination 192.168.1.222
# ROUTE TO WAN
-A POSTROUTING -s 192.168.1.0/24 -o eth0 -j MASQUERADE
COMMIT
# END RULES
# Don't delete these required lines, otherwise there will be errors
...
# End required lines:
# No Traffic User
-A ufw-before-output -m owner --uid-owner username-offline -j DROP

# Allow Local Traffic User
-A ufw-before-output -m owner --uid-owner username-local -s localhost -j ACCEPT
-A ufw-before-output -m owner --uid-owner username-local -j DROP
...
# DISABLE PING/ICMP
# ok icmp codes for INPUT
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j DROP
-A ufw-before-input -p icmp --icmp-type source-quench -j DROP
-A ufw-before-input -p icmp --icmp-type time-exceeded -j DROP
-A ufw-before-input -p icmp --icmp-type parameter-problem -j DROP
-A ufw-before-input -p icmp --icmp-type echo-request -j DROP
```

```bash
sudo ufw enable
sudo ufw default deny incoming

sudo ufw allow in on eth1
sudo ufw allow in on br0

sudo ufw status numbered
```


# wireless

```bash
sudo apt install hostapd
sudo ufw allow in on wlan0
```

`vim /etc/default/hostapd`

```
DAEMON_CONF="/etc/hostapd/hostapd.conf"
```

`vim /etc/hostapd/hostapd.conf`

#### 2.4 GHz 

```
interface=wlan0
bridge=br0
driver=nl80211

hw_mode=g
channel=2
# ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]
ht_capab=[HT40+]
ieee80211n=1
ieee80211d=1
wmm_enabled=1
wme_enabled=1
country_code=US

ssid=HOST_SSID_NAME
auth_algs=3
ignore_broadcast_ssid=0
wpa=3
wpa_passphrase=HOST_PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP              
# wpa_pairwise=TKIP
rsn_pairwise=CCMP
macaddr_acl=0
eap_reauth_period=360000000
```

#### 5 GHz

```
interface=wlan0
bridge=br0
driver=nl80211

hw_mode=a
channel=36
ht_capab=[HT40+]
vht_oper_chwidth=1
vht_oper_centr_freq_seg0_idx=42

ieee80211n=1
ieee80211ac=1
wmm_enabled=1
wme_enabled=1
country_code=US

ssid=HOST_SSID_NAME
auth_algs=3
ignore_broadcast_ssid=0
wpa=3
wpa_passphrase=HOST_PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP              
# wpa_pairwise=TKIP
rsn_pairwise=CCMP
macaddr_acl=0
eap_reauth_period=360000000
```

# reboot

### view clients

```bash
arp -a
# or
ip n | nslookup
```

### dnsmasq port 53 in use

```
sudo ss -lp "sport = :domain" | grep 'systemd-resolved' && \
  sudo systemctl stop systemd-resolved && \
  sudo systemctl disable systemd-resolved && \
  sudo systemctl mask systemd-resolved
```

# open vpn

`sudo vim /etc/openvpn/server.conf`

```
port 1234
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh2048.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 192.168.1.1"
keepalive 10 120
tls-auth ta.key 0
cipher AES-128-CBC 
comp-lzo
max-clients 4
user ovpn
group ovpn
persist-key
persist-tun
status openvpn-status.log
verb 3
;mute 20
auth SHA256
key-direction 0
;script-security 2
client-connect /etc/openvpn/clientconnect.sh
```

`sudo vim /etc/openvpn/clientconnect.sh`

```
#!/bin/bash
CONNECTION=$trusted_ip
touch /home/ovpn/clients.txt
if [ -z $trusted_ip ]; then CONNECTION="UNKNOWN IP"; fi
if grep -q "$CONNECTION" /home/ovpn/clients.txt; then exit 0; fi

curl -X POST --data-urlencode "payload={\"channel\": \"#CHANNEL_NAME\", \"username\": \"webhookbot\", \"text\": \"VPN connection made: $CONNECTION\", \"icon_emoji\": \":smiley:\"}" https://hooks.slack.com/services/SLACKWEBHOOK
echo $CONNECTION > /home/ovpn/clients.txt
}
```
