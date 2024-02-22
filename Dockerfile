FROM sonarqube:10.4.0-community

COPY ./filesystem /.
COPY ./filesystem-shared-ca-certificates /.

ARG _SERVER_KEY_PASSPHRASE

#RUN openssl rsa \
#  -in /etc/gitlab/ssl/private/server-encrypted.key \
#  -out /etc/gitlab/ssl/private/server.key \
#  -passin "pass:${_SERVER_KEY_PASSPHRASE}"

RUN bash /mnt/setup-ca.sh

EXPOSE 22 80 443 8081
