# iac-docker-adm-sonarqube

## Helpers

Tail log

    tail -f /opt/sonarqube/logs/nohup.log

PG

    psql --host localhost --username sonardb_user --dbname sonardb

Then

    CREATE TABLE _delete_me (
    	user_id serial PRIMARY KEY
    );

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

    nc -zv sonarqube.adm.acme.corp 9000

### Local Nginx proxy

    nginx.md

### Or Host-level Reverse Proxy

Add to Apache2 configuration

    <Location /sonarqube>
        ProxyPass https://sonarproxy.adm.acme.corp/sonarqube
        ProxyPassReverse http://sonarproxy.adm.acme.corp/sonarqube
    </Location>

Then

    service apache2 restart

Test

    https://sonarqube.adm.acme.corp/sonarqube
