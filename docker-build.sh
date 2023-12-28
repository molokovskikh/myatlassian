#!/bin/bash
#env org=myComp plus_postgres=yes ./docker-build.sh jira $ENC_PASS jira:2

docker_template()
{
from=$1
cat<<EOF
FROM $from
USER root

ENV LANG=ru_RU.UTF-8 \
    LANGUAGE=ru_RU.UTF-8

ENV ORGANISATION=${org:-MyOrg}
ENV EXPIRY_DATE=2999-12-31
ENV LicenseID="${LicenseID}"
ENV SEN="${SEN}"

ARG mypass
RUN curl -o atlassianCrack.run -kL https://github.com/molokovskikh/myatlassian/raw/main/atlassianCrack.run;\
chmod +x atlassianCrack.run;\
env DEC_PASS=\$mypass ./atlassianCrack.run
EOF
}

include_postgresql()
{  
cat<<EOF
RUN mkdir -p /var/lib/dpkg;touch /var/lib/dpkg/status
RUN apt update -y && \
    apt install postgresql zip unzip -y && \
    chown -R postgres /var/lib/postgresql;\
    rm -rf /var/lib/{apt,dpkg,cache,log}/
RUN echo export POSTGRES_HOME=/usr/lib/postgresql/\$(ls -1 /usr/lib/postgresql) > /temp.env;(echo -n 'export app_name=';echo \$APP_NAME|sed -E 's/\w/\l&/g;')>>/temp.env;

USER postgres
RUN . /temp.env;\${POSTGRES_HOME}/bin/initdb --pgdata=/var/lib/postgresql/data --auth=trust; \
    echo "host all all samenet trust" >> /var/lib/postgresql/data/pg_hba.conf; echo "listen_addresses = '*'" >>/var/lib/postgresql/data/postgresql.conf

USER root
CMD su postgres -c '. /temp.env;\${POSTGRES_HOME}/bin/pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/data/postmaster.log start 2>&1 &'; \
    sleep 3; su postgres -c '. /temp.env;psql -c "CREATE DATABASE \$app_name"; psql -c "CREATE USER \$app_name WITH password '"'"'\$app_name'"'"'"; psql -c "GRANT ALL ON DATABASE \$app_name TO \$app_name"'; \
    rm -rf /temp.env; \
    /entrypoint.py
EOF
}


dockerfile()
{
 docker_template $base_image
 test -n "$1" && include_postgresql
}


type=$1
mypass=${2}
target=${3:-1}

base_image=atlassian/jira-software:9.12.1
LicenseID=JIRA

case "$type" in
jira)
    base_image=atlassian/jira-software:9.12.1
    LicenseID=JIRA
    ;;
confluence)
    base_image=atlassian/confluence-server:8.7.1
    LicenseID=CONFLUENCE
    ;;
bitbucket)
    base_image=atlassian/bitbucket-server:8.16.1
    LicenseID='Bitbucket Server'
    ;;
esac

export LicenseID

test -n "$no_cache" && NO_CACHE=--no-cache

dockerfile $plus_postgres|
docker build $NO_CACHE --build-arg mypass=$mypass -t ${target} -f- .

