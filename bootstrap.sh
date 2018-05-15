#!/bin/bash

: ${HADOOP_PREFIX:=/usr/local/hadoop}

$HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

rm /tmp/*.pid

# installing libraries if any - (resource urls added comma separated to the ACP system variable)
cd $HADOOP_PREFIX/share/hadoop/common ; for cp in ${ACP//,/ }; do  echo == $cp; curl -LO $cp ; done; cd -

# kerberos client
sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" /etc/krb5.conf
sed -i "s/example.com/${DOMAIN_REALM}/g" /etc/krb5.conf

# update config files
sed -i "s/HOSTNAME/$(hostname -f)/g" $HADOOP_PREFIX/etc/hadoop/core-site.xml
sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_PREFIX/etc/hadoop/core-site.xml
sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_PREFIX/etc/hadoop/core-site.xml

sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml
sed -i "s/HOSTNAME/$(hostname -f)/g" $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml
sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml

sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_PREFIX/etc/hadoop/yarn-site.xml
sed -i "s/HOSTNAME/$(hostname -f)/g" $HADOOP_PREFIX/etc/hadoop/yarn-site.xml
sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_PREFIX/etc/hadoop/yarn-site.xml

sed -i "s/EXAMPLE.COM/${KRB_REALM}/g" $HADOOP_PREFIX/etc/hadoop/mapred-site.xml
sed -i "s/HOSTNAME/$(hostname -f)/g" $HADOOP_PREFIX/etc/hadoop/mapred-site.xml
sed -i "s#/etc/security/keytabs#${KEYTAB_DIR}#g" $HADOOP_PREFIX/etc/hadoop/mapred-site.xml

sed -i "s#/usr/local/hadoop/bin/container-executor#${NM_CONTAINER_EXECUTOR_PATH}#g" $HADOOP_PREFIX/etc/hadoop/yarn-site.xml

# create namenode kerberos principal and keytab
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey hdfs/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey mapred/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey yarn/$(hostname -f)@${KRB_REALM}"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey HTTP/$(hostname -f)@${KRB_REALM}"

kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k hdfs.keytab hdfs/$(hostname -f) HTTP/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k mapred.keytab mapred/$(hostname -f) HTTP/$(hostname -f)"
kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k yarn.keytab yarn/$(hostname -f) HTTP/$(hostname -f)"

mkdir -p ${KEYTAB_DIR}
mv hdfs.keytab ${KEYTAB_DIR}
mv mapred.keytab ${KEYTAB_DIR}
mv yarn.keytab ${KEYTAB_DIR}
chmod 400 ${KEYTAB_DIR}/hdfs.keytab
chmod 400 ${KEYTAB_DIR}/mapred.keytab
chmod 400 ${KEYTAB_DIR}/yarn.keytab
chown hdfs:hadoop ${KEYTAB_DIR}/hdfs.keytab
chown mapred:hadoop ${KEYTAB_DIR}/mapred.keytab
chown yarn:hadoop ${KEYTAB_DIR}/yarn.keytab

service ssh start

if [ "$1" == "--help" -o "$1" == "-h" ]; then
    echo "Usage: $(basename $0) (master|worker)"
    exit 0
elif [ "$1" == "master" ]; then
    yes| $HADOOP_PREFIX/bin/hdfs namenode -format

    nohup $HADOOP_PREFIX/bin/hdfs namenode 2>> /var/log/hadoop/namenode.err >> /var/log/hadoop/namenode.out &
    nohup $HADOOP_PREFIX/bin/yarn resourcemanager 2>> /var/log/hadoop/resourcemanager.err >> /var/log/hadoop/resourcemanager.out &
    nohup $HADOOP_PREFIX/bin/yarn timelineserver 2>> /var/log/hadoop/timelineserver.err >> /var/log/hadoop/timelineserver.out &
    nohup $HADOOP_PREFIX/bin/mapred historyserver 2>> /var/log/hadoop/historyserver.err >> /var/log/hadoop/historyserver.out &


    kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -randkey root@${KRB_REALM}"
    kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k /root/root.keytab root"

    kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "addprinc -pw hadoop-user hadoop-user@${KRB_REALM}"
    kadmin -p ${KERBEROS_ADMIN} -w ${KERBEROS_ADMIN_PASSWORD} -q "xst -k /home/hadoop-user/hadoop-user.keytab hadoop-user"
    chown hadoop-user:hadoop-user /home/hadoop-user/hadoop-user

    kinit -kt /root/root.keytab root

    hdfs dfsadmin -safemode wait
    while [ $? -ne 0 ]; do hdfs dfsadmin -safemode wait; done

    hdfs dfs -chown hdfs:hadoop /
    hdfs dfs -chmod 755 /
    hdfs dfs -mkdir /tmp
    hdfs dfs -chown hdfs:hadoop /tmp
    hdfs dfs -chmod -R 1777 /tmp
    hdfs dfs -mkdir /tmp/logs
    hdfs dfs -chown yarn:hadoop /tmp/logs
    hdfs dfs -chmod 1777 /tmp/logs

    hdfs dfs -mkdir -p /user/hadoop-user
    hdfs dfs -chown hadoop-user:hadoop-user /user/hadoop-user

    kdestroy

    while true; do sleep 1000; done
elif [ "$1" == "worker" ]; then
    nohup $HADOOP_PREFIX/bin/hdfs datanode 2>> /var/log/hadoop/datanode.err >> /var/log/hadoop/datanode.out &
    nohup $HADOOP_PREFIX/bin/yarn nodemanager 2>> /var/log/hadoop/nodemanager.err >> /var/log/hadoop/nodemanager.out &
    while true; do sleep 1000; done
elif [ $1 == "bash" ]; then
    /bin/bash
fi

