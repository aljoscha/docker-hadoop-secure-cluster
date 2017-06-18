# Creates pseudo distributed hadoop 2.7.1
#
# docker build -t sequenceiq/hadoop .

FROM sequenceiq/pam:centos-6.5
MAINTAINER Knappek

USER root

# install dev tools
RUN yum clean all; \
    rpm --rebuilddb; \
    yum install -y curl which tar sudo openssh-server openssh-clients rsync \ 
    vim rsyslog unzip glibc-devel
# update libselinux. see https://github.com/sequenceiq/hadoop-docker/issues/14
RUN yum update -y libselinux

RUN echo 'alias ll="ls -alF"' >> /root/.bashrc

# passwordless ssh
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

# java
# download/copy JDK. Comment one of these. The curl command can be retrieved
# from https://lv.binarybabel.org/catalog/java/jdk8
#RUN curl -LOH 'Cookie: oraclelicense=accept-securebackup-cookie' 'http://download.oracle.com/otn-pub/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jdk-8u131-linux-x64.rpm'
COPY local_files/jdk-8u131-linux-x64.rpm /

RUN rpm -i jdk-8u131-linux-x64.rpm
RUN rm jdk-8u131-linux-x64.rpm
ENV JAVA_HOME /usr/java/default
ENV PATH $PATH:$JAVA_HOME/bin
RUN rm /usr/bin/java && ln -s $JAVA_HOME/bin/java /usr/bin/java

RUN curl -LOH 'Cookie: oraclelicense=accept-securebackup-cookie' 'http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip'
RUN unzip jce_policy-8.zip
RUN cp /UnlimitedJCEPolicyJDK8/local_policy.jar /UnlimitedJCEPolicyJDK8/US_export_policy.jar $JAVA_HOME/jre/lib/security

RUN mkdir -p /tmp/native
# download/copy hadoop native support. Choose one of these options
#RUN curl -L https://github.com/sequenceiq/docker-hadoop-build/releases/download/v2.7.1/hadoop-native-64-2.7.1.tgz | tar -xz -C /tmp/native
COPY local_files/hadoop-native-64-2.7.1.tgz /tmp/native/hadoop-native-64-2.7.1.tgz
RUN tar -xzvf /tmp/native/hadoop-native-64-2.7.1.tgz -C /tmp/native

# Kerberos client
RUN yum install krb5-libs krb5-workstation krb5-auth-dialog -y
RUN mkdir -p /var/log/kerberos
RUN touch /var/log/kerberos/kadmind.log

# hadoop
# download/copy hadoop. Choose one of these options
#RUN curl -s http://www.eu.apache.org/dist/hadoop/common/hadoop-2.7.1/hadoop-2.7.1.tar.gz | tar -xz -C /usr/local/
COPY local_files/hadoop-2.7.1.tar.gz /usr/local/hadoop-2.7.1.tar.gz
RUN tar -xzvf /usr/local/hadoop-2.7.1.tar.gz -C /usr/local
RUN cd /usr/local && ln -s ./hadoop-2.7.1 hadoop

ENV HADOOP_PREFIX /usr/local/hadoop
ENV HADOOP_COMMON_HOME /usr/local/hadoop
ENV HADOOP_HDFS_HOME /usr/local/hadoop
ENV HADOOP_MAPRED_HOME /usr/local/hadoop
ENV HADOOP_YARN_HOME /usr/local/hadoop
ENV HADOOP_CONF_DIR /usr/local/hadoop/etc/hadoop
ENV YARN_CONF_DIR $HADOOP_PREFIX/etc/hadoop
ENV NM_CONTAINER_EXECUTOR_PATH $HADOOP_PREFIX/bin/container-executor
ENV HADOOP_BIN_HOME $HADOOP_PREFIX/bin
ENV PATH $PATH:$HADOOP_BIN_HOME

ENV KRB_REALM EXAMPLE.COM
ENV DOMAIN_REALM example.com
ENV KERBEROS_ADMIN admin/admin
ENV KERBEROS_ADMIN_PASSWORD admin
ENV KERBEROS_ROOT_USER_PASSWORD password
ENV KEYTAB_DIR /etc/security/keytabs
ENV FQDN hadoop.com

RUN mkdir $HADOOP_PREFIX/input
RUN cp $HADOOP_PREFIX/etc/hadoop/*.xml $HADOOP_PREFIX/input

ADD config_files/hadoop-env.sh $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
ADD config_files/core-site.xml $HADOOP_PREFIX/etc/hadoop/core-site.xml
ADD config_files/hdfs-site.xml $HADOOP_PREFIX/etc/hadoop/hdfs-site.xml
ADD config_files/mapred-site.xml $HADOOP_PREFIX/etc/hadoop/mapred-site.xml
ADD config_files/yarn-site.xml $HADOOP_PREFIX/etc/hadoop/yarn-site.xml
ADD config_files/ssl-server.xml $HADOOP_PREFIX/etc/hadoop/ssl-server.xml
ADD config_files/ssl-client.xml $HADOOP_PREFIX/etc/hadoop/ssl-client.xml
ADD config_files/keystore.jks $HADOOP_PREFIX/lib/keystore.jks
#ADD guava-16.0.1.jar /usr/local/hadoop-2.7.1/share/hadoop/common/lib/guava-16.0.1.jar
#ADD guava-16.0.1.jar /usr/local/hadoop-2.7.1/share/hadoop/httpfs/tomcat/webapps/webhdfs/WEB-INF/lib/guava-16.0.1.jar
#ADD guava-16.0.1.jar /usr/local/hadoop-2.7.1/share/hadoop/tools/lib/guava-16.0.1.jar
#ADD guava-16.0.1.jar /usr/local/hadoop-2.7.1/share/hadoop/hdfs/lib/guava-16.0.1.jar
#ADD guava-16.0.1.jar /usr/local/hadoop-2.7.1/share/hadoop/yarn/lib/guava-16.0.1.jar
#ADD guava-16.0.1.jar /usr/local/hadoop-2.7.1/share/hadoop/kms/tomcat/webapps/kms/WEB-INF/lib/guava-16.0.1.jar

# fixing the libhadoop.so like a boss
RUN rm -rf /usr/local/hadoop/lib/native
RUN mv /tmp/native /usr/local/hadoop/lib

ADD config_files/ssh_config /root/.ssh/config
RUN chmod 600 /root/.ssh/config
RUN chown root:root /root/.ssh/config

ENV BOOTSTRAP /etc/bootstrap.sh
ADD bootstrap.sh $BOOTSTRAP
RUN chown root:root $BOOTSTRAP
RUN chmod 700 $BOOTSTRAP


# workingaround docker.io build error
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh
RUN chmod +x /usr/local/hadoop/etc/hadoop/*-env.sh
RUN ls -la /usr/local/hadoop/etc/hadoop/*-env.sh

# fix the 254 error code
RUN sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
RUN echo "UsePAM no" >> /etc/ssh/sshd_config
RUN echo "Port 2122" >> /etc/ssh/sshd_config

CMD ["/etc/bootstrap.sh", "-d"]

# Hdfs ports
EXPOSE 50010 50020 50070 50075 50090 8020 9000
# Mapred ports
EXPOSE 10020 19888
#Yarn ports
EXPOSE 8030 8031 8032 8033 8040 8042 8088
#Other ports
EXPOSE 49707 2122
