#!/usr/bin/env bash

echo "Import custom cacerts to JRE"
keytool -import -trustcacerts \
        -keystore /opt/java/openjdk/lib/security/cacerts \
        -storepass changeit -noprompt \
        -alias iamcarsa \
        -file /usr/share/ca-certificates/self-signed/iamcarsa.crt

keytool -import -trustcacerts \
        -keystore /opt/java/openjdk/lib/security/cacerts \
        -storepass changeit -noprompt \
        -alias telephuscarsa \
        -file /usr/share/ca-certificates/self-signed/telephuscarsa.crt
