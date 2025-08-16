#!/bin/bash
#NOTICE: ISO should mount on /mnt ,or it will be error
DHCP_NIC="192.168.159.120"
NIC_NETMASK="255.255.255.0"
NIC_START="192.168.159.125"
NIC_END="192.168.159.130"
NIC_BROADCAST="192.168.159.255"
NIC_GATEWAY="192.168.159.2"

#install server
install_server() {
  yum -y install dhcp tftp-server httpd syslinux-4.05-15.el7.x86_64 
}
#dhcp-install-config
dhcp_install_config() {
  cp /usr/share/doc/dhcp-4.2.5/dhcpd.conf.example /etc/dhcp/
  mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
  cp /etc/dhcp/dhcpd.conf.example /etc/dhcp/dhcpd.conf

  sed -i "11anext-server ${DHCP_NIC};" /etc/dhcp/dhcpd.conf
  sed -i '12afilename "/pxelinux.0";' /etc/dhcp/dhcpd.conf
  sed -i "49/subnet 10.5.5.0 netmask 255.255.255.224/subnet ${DHCP_NIC} netmask ${NIC_NETMASK}/" /etc/dhcp/dhcpd.conf
  sed -i "50/range 10.5.5.26 10.5.5.30/range ${NIC_START} ${NIC_END}/" /etc/dhcp/dhcpd.conf
  sed -i "53/option routers 10.5.5.1/option routers ${NIC_GATEWAY}/" /etc/dhcp/dhcpd.conf
  sed -i "54/option broadcast-address 10.5.5.31/option broadcast-address ${NIC_BROADCAST}/" /etc/dhcp/dhcpd.conf

}


#tftp-server-config
tftp_server_config() {
  cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
  chmod 644 /var/lib/tftpboot/pxelinux.0
  mkdir pxelinux.cfg
  cd /mnt/isolinux || { echo "Error: /mnt/isolinux not found"; exit 1; }
  cp -r * /var/lib/tftpboot/
  cd /var/lib/tftpboot
  cp isolinux.cfg pxelinux.cfg/default

  sed -i '68d' pxelinux.cfg/default
  sed -i "s#inst.stage2=hd:LABEL=CentOS\x207\x20x86_64#inst.stage2=http://${DHCP_NIC}/iso inst.ks=http://{DHCP_NIC}/ks/ks.cfg#" pxelinux.cfg/default
  sed -i "62amenu default" pxelinux.cfg/default
}

#http-config
http_config() {
  mkdir /var/www/html/{iso,ks}
  cp /mnt/*  /var/www/html/iso
  cd
  cp anaconda-ks.cfg ks.cfg
  sed -i '5s#cdrom#url --url=http://${DHCP_NIC}/iso#' ks.cfg
  sed -i 's/network  --bootproto=dhcp --device=ens33 --ipv6=auto --activate/network  --bootproto=dhcp --activate' ks.cfg
  sed -i '/--none/d' ks.cfg
  sed -i '2areboot' ks.cfg
  cp ks.cfg /var/www/html/ks
  chmod 644 /var/www/html/ks/ks.cfg
}

#start service
start_service() {
  systemctl enable --now dhcpd tftp httpd
  systemctl status dhcpd tftp httpd || exit 1
}


main() {
  install_server
  dhcp_install_config
  tftp_server_config
  http_config
  start_service
}

main
