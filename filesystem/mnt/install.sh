#!/usr/bin/env bash
: "${SONAR_JDBC_PASSWORD?}"

##
echo "Install the base tools"

apt-get update
apt-get install -y \
 curl vim wget htop unzip gnupg2 \
 bash-completion git apt-transport-https ca-certificates \
 software-properties-common

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
