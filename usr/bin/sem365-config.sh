#! /bin/sh

usage ()
{
  echo 'Usage : install.sh -h <hostname> -g <GUID> -o <operator>'
  exit
}

while [ "$1" != "" ]; do
case $1 in
        -h )           shift
                       hostname=$1
                       ;;
        -g )           shift
                       GUID=$1
                       ;;
        -o )           shift
                       operator=$1
                       ;;
	* )            QUERY=$1
    esac
    shift
done

if [ "$hostname" = "" ]
then
    usage
fi
if [ "$GUID" = "" ]
then
    usage
fi
if [ "$operator" = "" ]
then
    usage
fi
echo "Все нормально, ща приступим! Имя указано=$hostname, GUID=$GUID, Сотовый оператор=$operator"

#######VARS##################################################
deb_rep=/etc/apt/sources.list
wb_rep=/etc/apt/sources.list.d/sem365.list
res_cfg=/opt/resident/semresident.xml
zabb_addr=zabbix.sem365.ru
zabbix_cfg=/etc/zabbix/zabbix_agentd.conf
host_metadata=wb
##############################################################
#remove all sources list
rm -rf /etc/apt/sources.list /etc/apt/sources.list.d/*
rm /etc/resolv.conf && touch /etc/resolv.conf
#disable WiFi
echo -e "blacklist 8723bu \nblacklist cfg80211" > /etc/modprobe.d/wireless.conf
#sem365 repo add
grep "deb [arch=armel] http://release.sem365.ru/ sem365 main" $wb_rep|| echo "deb [arch=armel] http://release.sem365.ru/ sem365 main" >>$wb_rep
#disable en for apt
echo 'Acquire::Languages "none";'>/etc/apt/apt.conf.d/00aptitude
#add trust ssh for main sem server
mkdir -p /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDGT1n0O0pNfFgTyu2ROoT6j0TLCG66P68+/v2fs2c4HqYDj3lFzmATubAXU2aFSZrYAVJa90EPwq+ZVi6TSiC8+0wpF18zj056L0mFoj5NCGIZEnbEiJyzFVO/2Jv0QnSC62QywndvJCPxKjdTjkNR5sFXkiN523WiEwGdhaDQaXAOFR8DBZuMHZ5Tw0uMxq6tL8z1MyAu5P8Gi3YO/q/qBbi3DsKu//jMKxRXv/onqmYCRksgKD9w7zDCQ/PfA8o+PUDgKknQqI2WcrrlYYgFG7MgAZhXl3YiF2AdJptAVkIBfvq4pIQMg5rudp23zgJKz88EGubhF9VyvPQxBXZp sem@sem01" >>/root/.ssh/authorized_keys

#add repo auth key
apt-key add keysem365
#install all deb packagen near install.sh
dpkg -i --force-all deb/*.deb

unlink /etc/wb-hardware.conf
unlink /etc/wb-homa-gpio.conf
unlink /etc/wb-mqtt-serial.conf
unlink /mnt/data/etc/hostapd.conf

#config hosts
grep "10.10.10.2 daq.sem365.ru" /etc/hosts || echo "10.10.10.2 daq.sem365.ru cnt.esavings.ru" >> /etc/hosts
grep "10.10.10.3 zabbix.sem365.ru" /etc/hosts || echo "10.10.10.3 release.sem365.ru zabbix.sem365.ru" >> /etc/hosts
grep "10.10.10.3 release.sem365.ru" /etc/hosts || echo "10.10.10.3 release.sem365.ru zabbix.sem365.ru" >> /etc/hosts

#config zabbix agent
cp wb.conf /etc/zabbix/zabbix_agentd.conf.d/
sed -i -e "s/\(Server=\).*/\1$zabb_addr/" $zabbix_cfg
sed -i -e "s/\(ServerActive=\).*/\1$zabb_addr/" $zabbix_cfg
sed -i -e "s/\(Hostname=\).*/\1$GUID/" $zabbix_cfg
sed -i -e "s/\(\# HostMetadata=\).*/HostMetadata=$host_metadata/" $zabbix_cfg
grep "^RefreshActiveChecks=3600" $zabbix_cfg || sed -i "/# RefreshActiveChecks=120/ a RefreshActiveChecks=3600" $zabbix_cfg
/etc/init.d/zabbix-agent restart

#cron zabbix
echo "*/1 * * * *	root	/sbin/ifconfig ppp0 | grep addr | awk -F: '{print \$2}' | awk '{print \$1}'  | xargs zabbix_sender -z zabbix.sem365.ru -p 10051 -s $GUID -k trap.ppp.IP -o ;" >/etc/cron.d/zabbix-agent
#ntp
cp ntp.conf /etc/
/usr/sbin/ntpdate -b -s release.sem365.ru

dpkg -i deb/resident/*.deb
#
rm -rf /etc/cron.daily/resident

cp set-default-route /etc/ppp/ip-up.d/
cp Beeline /etc/ppp/peers/
cp Megafon /etc/ppp/peers/
cp Mts /etc/ppp/peers
cp interfaces /etc/network/
cp timezone /etc/
cp localtime /etc/
cp -r wb-conf/* /etc/
cp hostapd.conf /etc/

#Set Operator and host in interface file
sed -i -e "s/\(hostname \).*/\1 $hostname/" /etc/network/interfaces
sed -i -e "s/\(provider \).*/\1$operator/" /etc/network/interfaces
echo $hostname > /etc/hostname
/etc/init.d/hostname.sh start

# autorun
update-rc.d resident defaults
ifdown ppp0>/dev/null
ifup ppp0

#apt-get update
#apt-get dist-upgrade

echo "Finished! \o/"
