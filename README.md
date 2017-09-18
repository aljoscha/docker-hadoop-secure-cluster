# Apache Hadoop 2.7.1 Docker image with Kerberos enabled

This project is a fork from [sequenceiq hadoop-docker](https://github.com/sequenceiq/hadoop-docker) 
and extends it with Kerberos enabled. With docker-compose 2 containers get
created, one with MIT KDC installed and one with a single node kerberized
Hadoop cluster.

The Docker image is also available on [Docker Hub](https://hub.docker.com/r/knappek/hadoop-secure/).

Versions
--------

* JDK8 
* Hadoop 2.7.1
* Maven 3.5.0


Run image
---------


Clone the [Github project](https://github.com/Knappek/docker-hadoop-secure) and run

```
docker-compose up -d
```

Usage
-----

Get the container name with `docker ps` and login to the container with

```
docker exec -it <container-name> /bin/bash
```


To obtain a Kerberos ticket, execute

```
kinit
```

where you will get prompted to enter your password. Afterwards you can use `hdfs` CLI like

```
hdfs dfs -ls /
```


Known issues
------------

### Unable to obtain Kerberos password

#### Error
docker-compose up fails for the first time with the error

```
Login failure for nn/hadoop.docker.com@EXAMPLE.COM from keytab /etc/security/keytabs/nn.service.keytab: javax.security.auth.login.LoginException: Unable to obtain password from user
```

#### Solution

Stop the containers with `docker-compose down` and start again with `docker-compose up -d`.


### JDK 8

Make sure you use download a JDK version that is still available. Old versions can be deprecated by Oracle and thus the download link won't be able anymore.

Get the latest JDK8 Download URL with

```
curl -s https://lv.binarybabel.org/catalog-api/java/jdk8.json
```

### Java Keystore

If the Keystroe has been expired, then create a new `keystore.jks`:

1. create private key

```
openssl genrsa -des3 -out server.key 1024
```

2. create csr

```
openssl req -new -key server.key -out server.csr`
```

3. remove passphrase in key
```
cp server.key server.key.org
openssl rsa -in server.key.org -out server.key
```

3. create self-signed cert
```
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt
```

4. create JKS and import certificate
```
keytool -import -keystore keystore.jks -alias CARoot -file server.crt`
```

