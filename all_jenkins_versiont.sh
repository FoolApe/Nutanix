#!/bin/bash
list="$PWD/node_list"
line=$(cat $PWD/node_list |wc -l)
key=$(cat /root/.ssh/id_rsa.pub)
date=`date +"%F %T"`
dns="10.240.150.101,10.240.150.102"
ntp="10.240.150.101,10.240.150.102"
sh="$PWD/ncli.sh"
all_ip_line=$(cat $PWD/node_list |awk '{print$ 3}'|sed "s/,/\n/g"|wc -l)
udp161="$PWD/161.sh"
log_path="$PWD/logs/"

[[ -d "$log_path" ]] || mkdir $log_path

function auto_nutanix_ssh(){
	for (( i=1; i<=${all_ip_line}; i++ ))
	do
        	all_ip=$(cat $list |awk '{print $3}'|sed -E "s/,/\n/g"|awk "NR==$i")
#        	echo ${all_ip}
#		echo ${key}
		sshpass -p "nutanix/4u" ssh -o "StrictHostKeyChecking=no" nutanix@${all_ip} "echo '${key}' >> /home/nutanix/.ssh/authorized_keys" >/dev/null 2>&1
            	{
       			if [ "$?" -eq  "0" ] ; then
				echo "CVM ${all_ip} add key success! next run devcls"
        		else    
				echo "CVM ${all_ip} add key fail! please check autossh and node_list"
				break
        		fi
            	} >> ${log_path}ssh.log
#		sleep 5
	done
}

function snmp_cron_161(){
	for (( i=1; i<=${all_ip_line}; i++ ))
	do	
		all_ip=$(cat $list |awk '{print $3}'|sed -E "s/,/\n/g"|awk "NR==$i")
	#	echo $all_ip
		scp -rp "${udp161}" nutanix@"${all_ip}":/tmp
        	{
        		if [ "$?" -eq  "0" ] ; then
				echo "CVM ${all_ip} scp script success!"
        		else    
				echo "CVM ${all_ip} scp script fail! please check udp161 and node_list"
				break
        		fi
		} >> ${log_path}sc161.log
		echo "==========${date} ${all_ip}===========" >> ${log_path}sc161.log
		ssh -T nutanix@"${all_ip}" << EOF >> ${log_path}sc161.log
sudo sed -i  's;@daily /usr/bin/timeout 24h bash -lc \"/home/nutanix/serviceability/bin/using-gflags /home/nutanix/serviceability/bin/send_alert_email_digest.py\";50 23 * * * /usr/bin/timeout 24h bash -lc \"/home/nutanix/serviceability/bin/using-gflags /home/nutanix/serviceability/bin/send_alert_email_digest.py\";' /var/spool/cron/nutanix
sudo systemctl restart crond
sudo sed -i "s/com2sec notConfigUser  default       public/com2sec notConfigUser  default       wdprd/" /etc/snmp/snmpd.conf
sudo sed -i '56a view    all     included        .1 80' /etc/snmp/snmpd.conf
sudo sed -i "s/systemview none none/all none none/" /etc/snmp/snmpd.conf
sudo sed -i "s/syslocation Unknown (edit \/etc\/snmp\/snmpd.conf)/syslocation WD-PRD/" /etc/snmp/snmpd.conf
sudo systemctl enable snmpd
sudo systemctl start snmpd
cd /tmp
bash 161.sh
exit
EOF
		{
	        	if [ "$?" -eq  "0" ] ; then
				echo "CVM ${all_ip} sc161 setting done"
            		else
				echo "CVM ${all_ip} web setting fail please check sc161 and node_list"
				break
            		fi
        	} >> ${log_path}sc161.log
       done
}	

function build_nutanix_clusters(){
	for (( i=1; i<=$line; i++ ))
	do
        	cls_snmp_name=$(cat $list |awk '{print $1}'|awk "NR==$i")
        	master_ip=$(cat $list |awk '{print $2}'|awk "NR==$i")
        	node_ips=$(cat $list |awk '{print $3}'|awk "NR==$i")
		echo "==========${date} ${cls_snmp_name} ${master_ip}===========" >> ${log_path}cls.log
#        	echo "$cls_snmp_name"
#        	echo "$master_ip"
#        	echo "$node_ips"
#           	echo $dns
#        	echo $ntp
		ssh -T  nutanix@"${master_ip}" << EOF >> ${log_path}cls.log 
cluster --dns_servers="${dns}" --ntp_servers="${ntp}" --redundancy_factor=2 -s "${node_ips}" --cluster_name="${cls_snmp_name}" create
exit
EOF
		sleep 20
#        	curl  http://${master_ip} -LkI >/dev/null 2>&1
#		{
#        		if [ "$?" -eq  "0" ] ; then
#				echo "Prism ${master_ip} web ok,next run scprun"
#        		else
#				echo "Prism ${master_ip} web fail!,please check script and node_list"
#		        break	
#        		fi
#		} >> ${log_path}cls.log
#		sleep 5
	done
}

function scp_run_ncli(){
	for (( i=1; i<=$line; i++ ))
	do
        	master_ip=$(cat $list |awk '{print $2}'| awk "NR==$i")
        	cls_snmp_name=$(cat $list |awk '{print $1}'|awk "NR==$i")
#        	echo "$cls_snmp_name"
#			echo "$master_ip"
        	scp -rp "${sh}" nutanix@"${master_ip}":/tmp
            	{
	    		if [ "$?" -eq  "0" ] ; then
				echo "CVM ${master_ip} scp script success!"
        		else    
				echo "CVM ${master_ip} scp script fail! please check scprun and node_list"
				break
        		fi
            	} >> ${log_path}ncli.log
		echo "==========${date} ${cls_snmp_name} ${master_ip}===========" >> ${log_path}ncli.log
        	ssh -T  nutanix@"${master_ip}" << EOF >> ${log_path}ncli.log
cd /tmp
bash ncli.sh
exit
EOF
		{
			if [ "$?" -eq  "0" ] ; then
				echo "Prism ${master_ip} web setting done,go next run sc161"
       			else
				echo "Prism ${master_ip} web setting fail please check ncli and node_list"
				break
        		fi
        	} >> ${log_path}ncli.log
	done
}
    case $Function in
	autossh)
		auto_nutanix_ssh
		exit
		;;
	devcls)
		build_nutanix_clusters
		exit
		;;
	scprun)
		scp_run_ncli
		exit
		;;
	sc161)
		snmp_cron_161
		exit
		;;
    esac
