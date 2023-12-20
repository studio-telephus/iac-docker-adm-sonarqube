# Sonarqube

## LXC server

Init container from base image

    lxc init images:debian/bullseye container-sonarqube

Network configuration

    lxc config device override container-sonarqube eth0
    lxc config device set container-sonarqube eth0 ipv4.address 10.0.10.125

Start & enter the container

    lxc start container-sonarqube
    lxc exec container-sonarqube -- /bin/bash

## Inside container-sonarqube

Pre-flight

    apt update && apt install -y vim curl wget htop openssh-server git unzip gnupg2 netcat

Add ssh key

    mkdir -p $HOME/.ssh
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDz+bA5VtpymU3cwqd1yrbsLNAzEdP5c+IVgb/OHlEzhLj7+ZOlWgWEFkoTTRJO3R1nU19yeMSKyAqG6xU+PWt8zlipgGfINuD168oytTM8UOmX16VZaAoUHFwAB+C7Xd814Os2FB7iXeolQVNRZADWUOF7/XOQVjEpbGVM5InoCvPTWPY9cFgRxJ2qwPZ08f0P6NupymK83LJYj9ELYlMfErxBF2WVObysw9c82oXq1VDLq+/clctVq+EhPkIhdRD1BIqNybQQnfvYnC1jfjHBSGIAfXtvJsjZ8TsHqFyXqOFYkj36/ZZ5GPBpIOsN1JA6NfF080g0Cz3iJohmjZh3 kristoa@telephus" > $HOME/.ssh/authorized_keys

OpenJDK 11

    openjdk.md

### Install Postgres 13

    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    apt-get update
    apt-get -y install postgresql-13

SSL permissions (anyone else other than root (user) and ssl-cert (group) can read and execute the ssl directory)

    chmod 716 /etc/ssl/private
    chown postgres:postgres /etc/ssl/private/ssl-cert-snakeoil.key

Enable Postgres service

    systemctl enable postgresql
    systemctl start postgresql

Change Postgres admin user's password to changeit

    passwd postgres

Create tablespace location for Postgres

    mkdir -p /mnt/postgresql/data
    chown -R postgres:postgres /mnt/postgresql

Create sonarqube user and database

    su postgres
    mkdir -p /mnt/postgresql/data/sonardb_tablespace
    psql

In console:

    CREATE USER sonardb_owner WITH ENCRYPTED PASSWORD 'changeit';

    CREATE TABLESPACE sonardb_tablespace OWNER sonardb_owner LOCATION '/mnt/postgresql/data/sonardb_tablespace';

    CREATE DATABASE sonardb OWNER sonardb_owner ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' TABLESPACE sonardb_tablespace;

    CREATE USER sonardb_user WITH ENCRYPTED PASSWORD 'changeit';

    GRANT CONNECT ON DATABASE sonardb TO sonardb_user;

    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO sonardb_user;

### Install Sonarqube

Pre-flight

    apt-get install -y ca-certificates lsb-release socat

Download

    wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.3.0.82913.zip 
    unzip sonarqube-*.zip -d /opt/
    mv /opt/sonarqube-* /opt/sonarqube

Create group & user
    
    groupadd sonargroup
    useradd -s /bin/false -g sonargroup -d /opt/sonarqube sonarqube
    chown -R sonarqube:sonargroup /opt/sonarqube

Create data folders

    mkdir -p /mnt/sonarqube/data
    mkdir -p /mnt/sonarqube/temp
    chown -R sonarqube:sonargroup /mnt/sonarqube

Setting the Access to the Database in /opt/sonarqube/conf/sonar.properties

    sonar.jdbc.username=sonardb_user
    sonar.jdbc.password=changeit
    sonar.jdbc.url=jdbc:postgresql://localhost/sonardb?currentSchema=public

Configuring the Elasticsearch storage for dedicated I/O volume

    sonar.path.data=/mnt/sonarqube/data
    sonar.path.temp=/mnt/sonarqube/temp
    sonar.path.logs=/mnt/sonarqube/logs

Create systemd files for sonarqube at /etc/systemd/system/sonarqube.service

    [Unit]
    Description=SonarQube Service
    After=syslog.target network.target
    
    [Service]
    Type=forking
    
    ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
    ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
    # change to your user
    User=sonarqube
    Group=sonargroup
    RestartSec=10
    Restart=always
    UMask=0007
    LimitNOFILE=65536
    
    [Install]
    WantedBy=multi-user.target

### Edit /etc/sysctl.conf in root host (Elasticsearch)

    vm.max_map_count=262144

Then

    sysctl -p
    lxc-stop -n container-sonarqube
    lxc-start -n container-sonarqube

### Start Sonarqube service

Autorun the sonarqube service

    systemctl enable sonarqube

Start the sonarqube service

    systemctl start sonarqube

Test

    nc -zv sonarqube.dev.acme.corp 9000

### Local Nginx proxy

    nginx.md

### Or Host-level Reverse Proxy

Add to Apache2 configuration in /etc/apache2/sites-available/telephus.k-space.ee.conf

    <Location /sonarqube>
        ProxyPass http://sonarqube.dev.acme.corp:9000/sonarqube
        ProxyPassReverse http://sonarqube.dev.acme.corp:9000/sonarqube
    </Location>

Then

    service apache2 restart

Test

    https://sonarqube.dev.acme.corp/sonarqube

### Post-installation

Trust self-signed certificates

    /usr/lib/jvm/jdk-11/bin/keytool -import -trustcacerts \
        -keystore /usr/lib/jvm/jdk-11/lib/security/cacerts \
        -storepass changeit -noprompt \
        -alias franciumca \
        -file /opt/acme-pki.git/self-signed/franciumca.cer

    /usr/lib/jvm/jdk-11/bin/keytool -import -trustcacerts \
        -keystore /usr/lib/jvm/jdk-11/lib/security/cacerts \
        -storepass changeit -noprompt \
        -alias francium-iamca \
        -file /opt/acme-pki.git/self-signed/iamca.cer
