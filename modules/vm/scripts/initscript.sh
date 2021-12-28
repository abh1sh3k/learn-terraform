#!/usr/bin/bash
> /tmp/init.log

systemctl enable firewalld
systemctl restart firewalld
systemctl restart docker

export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
export NOMAD_CACERT="/etc/nomad/nomad-ca.pem"
export NOMAD_CLIENT_KEY="/etc/nomad/cli-key.pem"
export NOMAD_CLIENT_CERT="/etc/nomad/cli.pem"
export NOMAD_ADDR=https://localhost:4646

SER_INSTALL_PATH=/opt/heal
interface_name=`ip r | grep private_ip | awk '{print $3}'`

DB_IP=private_ip
ROOT_DB_USER='admin'
DB_USER='test'
DB_PASS='test_1'
DB_PORT='3307'
export MYSQL_PWD='root@123'

yes | cp -f /tmp/keycloak_details.json.tpl ${SER_INSTALL_PATH}/XYZ_Service/conf-template/ui-service/ 
yes | cp -f /tmp/keycloak_details.json.tpl ${SER_INSTALL_PATH}/XYZ_Service/conf-template/controlpanel/
yes | cp -f /tmp/mle.crt /etc/nginx/
yes | cp -f /tmp/mle.key /etc/nginx/

echo "updating nomad consul config files" >> /tmp/init.log

sed -i "s/[1-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/private_ip/g" /etc/nomad/nomad_*
sed -i "s/[1-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/private_ip/g" /etc/consul/consul_*
sed -i "s/network_interface = \"eth0\"/network_interface = \"${interface_name}\"/g" /etc/nomad/nomad_*
sed -i "s/address   = \"private_ip:8501\"/address   = \"127.0.0.1:8501\"/g" /etc/nomad/nomad_*

echo "updating hosts files" >> /tmp/init.log
sed -i "4,5s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/private_ip/" /etc/hosts

echo "updating keycload json file" >> /tmp/init.log
sed -i "s/hostname/ip/" ${SER_INSTALL_PATH}/XYZ_Service/conf-template/ui-service/keycloak_details.json.tpl
sed -i "s/hostname/ip/" ${SER_INSTALL_PATH}/XYZ_Service/conf-template/controlpanel/keycloak_details.json.tpl
sed -i "s/13.92.103.30/public_ip/g" /etc/nginx/nginx.conf
sed -i "s/13.92.103.30:8443/public_ip:8443/g" ${SER_INSTALL_PATH}/nomadFile/standalone-ha.xml

systemctl restart nginx

echo "updating nomad file ip" >> /tmp/init.log

cd ${SER_INSTALL_PATH}/nomadFile
for file in `ls *.nomad`
do
        sed -i "s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/private_ip/g" $file
done

sed -i "s/consul kv get //g" ${SER_INSTALL_PATH}/nomadFile/jaeger.nomad
sed -i "s/memory = .*/memory = 2048/g" ${SER_INSTALL_PATH}/nomadFile/flink.nomad
sed -i "s/memory = .*/memory = 4096/g" ${SER_INSTALL_PATH}/nomadFile/keycloak.nomad
sed -i "s/memory = .*/memory = 1524/g" ${SER_INSTALL_PATH}/nomadFile/opensearch.nomad
sed -i "s/memory = .*/memory = 1024/g" ${SER_INSTALL_PATH}/nomadFile/flink.nomad

systemctl stop nomad
rm -rf ${SER_INSTALL_PATH}/nomad

echo "Service restarting" >> /tmp/init.log

systemctl restart consul
sleep 5
systemctl start nomad
systemctl restart ran

counter=1
CFLAG=0
while [ ${counter} -lt 60 ]
do
        echo "Checking consul is up !" >> /tmp/init.log
        consul info | grep leader | grep true >> /tmp/init.log 2>&1
        if [ $? -eq 0 ]; then
                CFLAG=1
                break
        fi
        counter=`expr $counter + 1`
        sleep 5
done

if [ $CFLAG -eq 0 ]; then
        echo "Consul did not start. Please check manually" >> /tmp/init.log
        exit 1
fi
echo "updating consul keys"
for i in `consul kv get -recurse | grep -w ip | grep -v keycloak`
do
        key=`echo $i | awk -F: '{print $1}'`
        consul kv put $key private_ip
done

consul kv put service/keycloak/ip customer_name.saas.xyz.com
consul kv put service/xyz/ip public_ip
consul kv put service/cassandra/node1/CASSANDRA_BROADCAST_ADDRESS private_ip
consul kv put service/keycloak/standaloneips private_ip
consul kv put service/mle/analyticsws/cors_domains "https://private_ip:8443"
consul kv put service/upgrade/localnode private_ip
consul kv put service/upgrade/nodes "{'server-01': 'private_ip' }"

counter=1
CFLAG=0
while [ ${counter} -lt 60 ]
do
        echo "Checking nomad is up !" >> /tmp/init.log
        nomad server members | grep -v Name | awk '{print $5}' | grep true >> /tmp/init.log 2>&1
        if [ $? -eq 0 ]; then
                CFLAG=1
                break
        fi
        counter=`expr $counter + 1`
        sleep 5
done

if [ $CFLAG -eq 0 ]; then
        echo "Nomad did not start. Please check manually" >> /tmp/init.log
        exit 1
fi

nomad run ${SER_INSTALL_PATH}/nomadFile/percona.nomad
sleep 60
counter=1
CFLAG=0
while [ ${counter} -lt 60 ]
do
        echo "Checking percona is up !" >> /tmp/init.log
        nomad status percona | grep "^Status" | grep "running" >> /tmp/init.log 2>&1
        if [ $? -eq 0 ]; then
                CFLAG=1
                break
        fi
        counter=`expr $counter + 1`
        sleep 5
done

if [ $CFLAG -eq 0 ]; then
        echo "Percona did not start. Please check manually" >> /tmp/init.log
        exit 1
fi

sleep 20

mysql -h private_ip -u admin -p'root@123' -P 3307 --ssl-mode=disabled -e "update mysql.user set host=\'private_ip\' where host='10.0.0.4';"
cd ..
mv ${SER_INSTALL_PATH}/nomadFile/jaeger.nomad ${SER_INSTALL_PATH}/nomadFile/opensearch.nomad /tmp/
./startServices.sh ALL ALL
mv /tmp/opensearch.nomad /tmp/jaeger.nomad ${SER_INSTALL_PATH}/nomadFile/
