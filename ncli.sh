#!/bin/bash
#Admin Password
ncli user reset-password user-name=admin password=1qaz@WSX3edc
sleep 10

#Password_policy
sudo chage -m 0 -M 99999 -I -1 -E -1 admin
sleep 10

#Pulse disabled
ncli pulse-config update enable="false"
sleep 10

#SNMP UDP161
ncli snmp add-transport protocol="UDP" port="161"
sleep 10

#SNMPv3
ncli snmp add-user username="zabbix" auth-key="1qaz@WSX3edc" auth-type="SHA" priv-key="1qaz@WSX3edc" priv-type="AES"
sleep 10

#Time Zone
expect << EOF
spawn ncli cluster set-timezone timezone=Asia/Taipei
expect "Do you want to continue.(y/N)?:"
send "y\r"
expect eof;
EOF
sleep 10

#Alert Email
ncli alerts edit-alert-config enable="true" enable-default-nutanix-email="false" email-contacts="notificationwdprd@gangutech.com"
sleep 10

#SMTP Server
cls_name=`ncli cluster info |grep "Cluster Name" |awk '{print $4}'`
ncli cluster set-smtp-server port=25 from-email-address="${cls_name}"@wudi01.net address=10.240.146.99
sleep 10

#vCenter registration
ncli  managementserver register ip-address="10.240.146.100" port="443" admin-username="administrator@vsphere.local" admin-password="P@ssw0rd"
sleep 10

#Health-check,disable Cvm & Host password warning & Pluse conent check & Pluse check
ncli health-check edit id="6214" enable="false"
ncli health-check edit id="6213" enable="false"
ncli health-check edit id="140001" enable="false"
ncli health-check edit id="1077" enable="false"
ncli health-check edit id="103090" enable="false"
ncli health-check edit id="3026" enable="false"
sleep 10

#Storage name
ste_old_name=`ncli sp list | grep -i name | awk '{print $3}'`
ste_new_name=`ncli cluster info |grep "Cluster Name"|awk '{print $4}' |sed 's/-NTNX//g' |sed 's/-//' |sed 's/$/SP01/'`
ncli sp  edit name="${ste_old_name}" new-name="${ste_new_name}"
sleep 10

#Storage Container name
ste_con_old_name=`ncli ctr list | grep -i VStore | grep -i default | awk '{print $4}'`
ste_con_new_name=`ncli cluster info |grep "Cluster Name"|awk '{print $4}' |sed 's/-NTNX//g' |sed 's/-//' |sed 's/$/CON01/'`
ncli container edit name="${ste_con_old_name}" new-name="${ste_con_new_name}" enable-compression="true"  compression-delay="0"
sleep 10

#NFS mount ESXi
ste_con_name=`ncli container list |grep -i VStore |egrep "WDP|EC|ECP" |awk '{print $4}'`
ncli datastore add name="${ste_con_name}" ctr-name="${ste_con_name}"
sleep 10
