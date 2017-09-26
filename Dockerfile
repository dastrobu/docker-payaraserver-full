FROM openjdk:8-jdk

RUN \
 apt-get update && \ 
 apt-get install -y unzip 

ENV ADMIN_USER admin

ENV PAYARA_PATH /opt/payara50

RUN \ 
 useradd -b /opt -m -s /bin/bash -d ${PAYARA_PATH} -g 0 payara && echo payara:payara | chpasswd && \
 mkdir -p ${PAYARA_PATH}/deployments && \
 chmod -R g+w ${PAYARA_PATH}

# specify Payara version to download
ENV PAYARA_PKG https://oss.sonatype.org/service/local/artifact/maven/redirect?r=snapshots&g=fish.payara.distributions&a=payara&v=5.0.0.174-SNAPSHOT&p=zip
ENV PAYARA_VERSION 5-SNAPSHOT

ENV PKG_FILE_NAME payara-full-${PAYARA_VERSION}.zip

# Download Payara Server and install
RUN \
 wget --quiet -O /opt/${PKG_FILE_NAME} ${PAYARA_PKG} && \
 unzip -qq /opt/${PKG_FILE_NAME} -d /opt && \
 chown -R payara /opt && \
 chmod -R g+rw /opt && \
 chgrp -R 0 /opt && \
 # cleanup
 rm /opt/${PKG_FILE_NAME}

USER payara
RUN umask g+rw
WORKDIR ${PAYARA_PATH}

# set credentials to admin/admin 

ENV ADMIN_PASSWORD admin

RUN echo 'AS_ADMIN_PASSWORD=\n\
AS_ADMIN_NEWPASSWORD='${ADMIN_PASSWORD}'\n\
EOF\n'\
>> /opt/tmpfile

RUN echo 'AS_ADMIN_PASSWORD='${ADMIN_PASSWORD}'\n\
EOF\n'\
>> /opt/pwdfile

 # domain1
RUN ${PAYARA_PATH}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/opt/tmpfile change-admin-password && \
 ${PAYARA_PATH}/bin/asadmin start-domain domain1 && \
 ${PAYARA_PATH}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/opt/pwdfile enable-secure-admin && \
 ${PAYARA_PATH}/bin/asadmin stop-domain domain1

 # payaradomain
RUN \
 ${PAYARA_PATH}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/opt/tmpfile change-admin-password --domain_name=payaradomain && \
 ${PAYARA_PATH}/bin/asadmin start-domain payaradomain && \
 ${PAYARA_PATH}/bin/asadmin --user ${ADMIN_USER} --passwordfile=/opt/pwdfile enable-secure-admin && \
 ${PAYARA_PATH}/bin/asadmin stop-domain payaradomain

# cleanup
RUN rm /opt/tmpfile

ENV PAYARA_DOMAIN domain1
ENV DEPLOY_DIR ${PAYARA_PATH}/deployments
ENV AUTODEPLOY_DIR ${PAYARA_PATH}/glassfish/domains/${PAYARA_DOMAIN}/autodeploy

# Default payara ports to expose
EXPOSE 4848 8009 8080 8181

ENV DEPLOY_COMMANDS=${PAYARA_PATH}/post-boot-commands.asadmin
COPY generate_deploy_commands.sh ${PAYARA_PATH}/generate_deploy_commands.sh
USER 0
RUN \
 chown payara ${PAYARA_PATH}/generate_deploy_commands.sh && \
 chgrp 0 ${PAYARA_PATH}/generate_deploy_commands.sh && \
 chmod g+x ${PAYARA_PATH}/generate_deploy_commands.sh && \
 chmod -R g+rw /opt

USER payara


# ENTRYPOINT ${PAYARA_PATH}/generate_deploy_commands.sh && ${PAYARA_PATH}/bin/asadmin start-domain -v --postbootcommandfile ${DEPLOY_COMMANDS} ${PAYARA_DOMAIN}
ENTRYPOINT ["tail", "-t", "/dev/null"]
