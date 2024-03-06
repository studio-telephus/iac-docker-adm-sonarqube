FROM sonarqube:10.4.1-community

COPY ./filesystem /.
COPY ./filesystem-shared-ca-certificates /.

USER root

RUN bash /mnt/setup-ca.sh
RUN bash /mnt/install-overlay.sh

USER sonarqube

EXPOSE 9000
