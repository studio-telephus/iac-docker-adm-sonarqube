# iac-lxd-adm-sonarqube

## Helpers

Tail log

    tail -f /opt/sonarqube/logs/nohup.log

SSL permissions (anyone else other than root (user) and ssl-cert (group) can read and execute the ssl directory)

    chmod 716 /etc/ssl/private
    chown postgres:postgres /etc/ssl/private/ssl-cert-snakeoil.key

Change user's password to changeit

    echo "$POSTGRES_PASSWORD" | passwd postgres --stdin

Edit /etc/sysctl.conf in root host (Elasticsearch)

    vm.max_map_count=262144

Then

    sysctl -p
    lxc-stop -n container-sonarqube
    lxc-start -n container-sonarqube

Test

    nc -zv sonarqube.dev.acme.corp 9000

### Local Nginx proxy

    nginx.md

### Or Host-level Reverse Proxy

Add to Apache2 configuration

    <Location /sonarqube>
        ProxyPass http://sonarqube.dev.acme.corp:9000/sonarqube
        ProxyPassReverse http://sonarqube.dev.acme.corp:9000/sonarqube
    </Location>

Then

    service apache2 restart

Test

    https://sonarqube.dev.acme.corp/sonarqube
