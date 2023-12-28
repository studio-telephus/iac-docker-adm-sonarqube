#!/usr/bin/env bash
: "${POSTGRES_PASSWORD?}"
: "${SONAR_OWNER_PASSWORD?}"
: "${SONAR_USER_PASSWORD?}"
: "${SERVER_KEY_PASSPHRASE?}"

##
echo "Install the base tools"

apt-get update
apt-get install -y \
 curl vim wget htop unzip gnupg2 lsb-release socat \
 bash-completion software-properties-common

## Run pre-install scripts
sh /mnt/setup-ca.sh


##
echo "Install JDK"

### Import the Corretto public key and then add the repository to the system list
wget -O - https://apt.corretto.aws/corretto.key | gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg && \
echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | tee /etc/apt/sources.list.d/corretto.list

### After the repo has been added, you can install Corretto 21
apt-get update
apt-get install -y java-17-amazon-corretto-jdk

### Verify the installation
java -version


echo "Install Postgres 15"
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
apt-get update
apt-get -y install postgresql-15


echo "Enable Postgres service"
systemctl enable postgresql
systemctl start postgresql

echo "Change Postgres user's password"
sudo -iu postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"

cat << EOF > /root/.pgpass
localhost:5432:postgres:postgres:$POSTGRES_PASSWORD
localhost:5432:sonardb:postgres:$POSTGRES_PASSWORD
localhost:5432:sonardb:sonardb_user:$SONAR_USER_PASSWORD
EOF

chmod 600 /root/.pgpass
export PGPASSFILE="/root/.pgpass"

echo "Create tablespace location for Postgres"
mkdir -p /mnt/postgresql/data/sonardb_tablespace
chown -R postgres:postgres /mnt/postgresql

echo "Create sonarqube user and database"
cat << EOF > /tmp/sonardb_setup.sql
CREATE USER sonardb_owner WITH ENCRYPTED PASSWORD '$SONAR_OWNER_PASSWORD';
CREATE TABLESPACE sonardb_tablespace OWNER sonardb_owner LOCATION '/mnt/postgresql/data/sonardb_tablespace';
CREATE DATABASE sonardb OWNER sonardb_owner ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' TABLESPACE sonardb_tablespace;
CREATE USER sonardb_user WITH ENCRYPTED PASSWORD '$SONAR_USER_PASSWORD';
GRANT CONNECT ON DATABASE sonardb TO sonardb_user;
\c sonardb
GRANT ALL ON SCHEMA public TO sonardb_user;
EOF

psql --host=localhost \
  --dbname=postgres \
  --port=5432 \
  --username=postgres \
  --file=/tmp/sonardb_setup.sql \
  --output=/tmp/sonardb_setup.out

echo "Download LTS"
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.3.79811.zip
unzip sonarqube-*.zip -d /opt/
mv /opt/sonarqube-* /opt/sonarqube

echo "Create group & user"
groupadd sonargroup
useradd -s /bin/false -g sonargroup -d /opt/sonarqube sonarqube


echo "Create data folders"
mkdir -p /mnt/sonarqube/data
mkdir -p /mnt/sonarqube/temp


echo "Configure sonarqube"
cat << EOF > /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonardb_user
sonar.jdbc.password=$SONAR_USER_PASSWORD
sonar.jdbc.url=jdbc:postgresql://localhost/sonardb
sonar.web.context=/sonarqube
sonar.path.data=/mnt/sonarqube/data
sonar.path.temp=/mnt/sonarqube/temp
sonar.path.logs=/mnt/sonarqube/logs
EOF

chown -R sonarqube:sonargroup /opt/sonarqube
chown -R sonarqube:sonargroup /mnt/sonarqube

echo "Create systemd file"
cat << EOF > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube Service
After=syslog.target network.target

[Service]
Type=forking

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonargroup
RestartSec=10
Restart=always
UMask=0007
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF


echo "Autorun the sonarqube service"
systemctl enable sonarqube

echo "Start the sonarqube service"
systemctl start sonarqube

echo "Java to trust Telephus self-signed certificates"
keytool -import -trustcacerts \
        -keystore /usr/lib/jvm/java-17-amazon-corretto/lib/security/cacerts \
        -storepass changeit -noprompt \
        -alias iamcarsa \
        -file /usr/share/ca-certificates/self-signed/iamcarsa.crt

keytool -import -trustcacerts \
        -keystore /usr/lib/jvm/java-17-amazon-corretto/lib/security/cacerts \
        -storepass changeit -noprompt \
        -alias telephuscarsa \
        -file /usr/share/ca-certificates/self-signed/telephuscarsa.crt

##
echo "Install nginx"

apt install nginx -y
systemctl enable nginx

chmod -R 700 /etc/ssl/private
openssl dhparam -out /etc/nginx/dhparam.pem 4096

echo "The private key is encrypted using PBE with 256 bit AES CBC."
openssl rsa \
  -in /etc/ssl/private/server-encrypted.key \
  -out /etc/ssl/private/server.key \
  -passin "pass:$SERVER_KEY_PASSPHRASE"

cat << EOF > /etc/nginx/conf.d/ssl.conf
server {
    listen 443 http2 ssl;
    listen [::]:443 http2 ssl;

    server_name localhost;

    ssl_certificate /etc/ssl/certs/server-chain.crt;
    ssl_certificate_key /etc/ssl/private/server.key;

    ssl_protocols TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/nginx/dhparam.pem;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_ecdh_curve secp384r1; # Requires nginx >= 1.1.0
    ssl_session_timeout  10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off; # Requires nginx >= 1.5.9
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    root /usr/share/nginx/html;

    location / {
    }

    error_page 404 /404.html;
    location = /404.html {
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
    }

    location /sonarqube {
        proxy_pass http://127.0.0.1:9000/sonarqube;
    }
}
EOF

echo "Make sure that there are no syntax errors in our files."
nginx -t

systemctl restart nginx
