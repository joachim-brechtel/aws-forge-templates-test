#!/bin/bash

set -e

. /etc/init.d/atl-functions
. /etc/init.d/atl-confluence-common

trap 'atl_error ${LINENO}' ERR

ATL_SYNCHRONY_STACK_SPACE=${ATL_SYNCHRONY_STACK_SPACE:?"The Stack Space of Synchrony must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_SYNCHRONY_MEMORY=${ATL_SYNCHRONY_MEMORY:?"The Memory of Synchrony must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_SYNCHRONY_WAITING_CONFIG_TIME=${ATL_SYNCHRONY_WAITING_CONFIG_TIME:?"The time waiting for Synchrony configuration must be supplied in ${ATL_FACTORY_CONFIG}"}

ATL_SYNCHRONY_SERVICE_NAME="synchrony"
ATL_CONFLUENCE_SHARED_CONFIG_FILE="${ATL_CONFLUENCE_SHARED_HOME}/confluence.cfg.xml"
ATL_CONFLUENCE_JRE_HOME="${ATL_CONFLUENCE_INSTALL_DIR}/jre/bin"
ATL_SYNCHRONY_JAR_PATH="${ATL_CONFLUENCE_INSTALL_DIR}/confluence/WEB-INF/othes/synchrony-standalone.jar"
# potential bug if we bump new version of driver ???
ATL_POSTGRES_DRIVER_PATH="${ATL_CONFLUENCE_INSTALL_DIR}/confluence/WEB-INF/lib/postgresql-9.4.1210.jar"

SYNCHRONY_JWT_PRIVATE_KEY=""
SYNCHRONY_JWT_PUBLIC_KEY=""

_RUNJAVA="${ATL_CONFLUENCE_JRE_HOME}/java"
SYNCHRONY_CLASSPATH="${ATL_SYNCHRONY_JAR_PATH}:${ATL_POSTGRES_DRIVER_PATH}"

# main method of this service
function start {
    atl_log "=== BEGIN: service atl-init-synchrony start ==="
    atl_log "Initialising Synchrony for ${ATL_CONFLUENCE_FULL_DISPLAY_NAME}"
    installConfluence
    configureConfluenceHome
    goSynchrony
    atl_log "=== END:   service atl-init-synchrony start ==="
}

function waitForConfluenceConfigInSharedHome() {
    atl_log "=== BEGIN: Waiting for confluence.cfg.xml avalaible in shared home folder ==="
    while [[ ! -f ${ATL_CONFLUENCE_SHARED_CONFIG_FILE} ]]; do
	  sleep ${ATL_SYNCHRONY_WAITING_CONFIG_TIME}
	  atl_log "====== :   Keep waiting for ${ATL_SYNCHRONY_WAITING_CONFIG_TIME} seconds ======"
	done
	SYNCHRONY_JWT_PRIVATE_KEY=$(xmllint --nocdata --xpath '//properties/property[@name="jwt.private.key"]/text()' ${ATL_CONFLUENCE_SHARED_CONFIG_FILE})
    SYNCHRONY_JWT_PUBLIC_KEY=$(xmllint --nocdata --xpath '//properties/property[@name="jwt.public.key"]/text()' ${ATL_CONFLUENCE_SHARED_CONFIG_FILE})
	while [[ -z ${SYNCHRONY_JWT_PRIVATE_KEY} ]]; do
	    atl_log "====== :   Could not load value for jwt.private.key will wait for next ${ATL_SYNCHRONY_WAITING_CONFIG_TIME} seconds before reload ======"
	    sleep ${ATL_SYNCHRONY_WAITING_CONFIG_TIME}
	    SYNCHRONY_JWT_PRIVATE_KEY=$(echo 'cat //properties/property[@name="jwt.private.key"]/text()' | xmllint --nocdata --shell ${ATL_CONFLUENCE_SHARED_CONFIG_FILE} | sed '1d;$d')
        SYNCHRONY_JWT_PUBLIC_KEY=$(echo 'cat //properties/property[@name="jwt.public.key"]/text()' | xmllint --nocdata --shell ${ATL_CONFLUENCE_SHARED_CONFIG_FILE} | sed '1d;$d')
	done

	atl_log "=== END: Waiting for confluence.cfg.xml avalaible in shared home folder ==="
}

# start Synchrony service
function goSynchrony {
    atl_log "Starting ${ATL_SYNCHRONY_SERVICE_NAME} service"
    waitForConfluenceConfigInSharedHome
    SYNCHRONY_PROPERTIES="\
${ATL_SYNCHRONY_STACK_SPACE} ${ATL_SYNCHRONY_MEMORY} \
-classpath ${SYNCHRONY_CLASSPATH} \
-Dreza.cluster.impl=hazelcast-micros \
-Dreza.database.url=${ATL_JDBC_URL} \
-Dreza.database.username=${ATL_JDBC_USER} \
-Dreza.database.password=${ATL_JDBC_PASSWORD} \
-Dreza.bind=localhost \
-Dreza.cluster.bind=${AWS_EC2_PRIVATE_IP} \
-Dcluster.interfaces=${AWS_EC2_PRIVATE_IP} \
-Dreza.cluster.base.port=25500 \
-Dreza.cluster.bind=${AWS_EC2_PRIVATE_IP} \
-Dreza.service.url=http://${AWS_EC2_PRIVATE_IP}:8091/synchrony \
-Dreza.context.path=/synchrony \
-Dreza.port=8091 \
-Dcluster.name=Synchrony-Cluster \
-Dcluster.join.type=aws \
-Djwt.private.key=${SYNCHRONY_JWT_PRIVATE_KEY} \
-Djwt.public.key=${SYNCHRONY_JWT_PUBLIC_KEY} \
-Dip.whitelist=something \
-Dauth.tokens=dummy \
-Dopenid.return.uri=http://example.com \
-Ddynamo.events.table.name=5 \
-Ddynamo.snapshots.table.name=5 \
-Ddynamo.secrets.table.name=5 \
-Ddynamo.limits.table.name=5 \
-Ddynamo.events.app.read.provisioned.default=5 \
-Ddynamo.events.app.write.provisioned.default=5 \
-Ddynamo.snapshots.app.read.provisioned.default=5 \
-Ddynamo.snapshots.app.write.provisioned.default=5 \
-Ddynamo.max.item.size=5 \
-Ds3.synchrony.bucket.name=5 \
-Ds3.synchrony.bucket.path=5 \
-Ds3.synchrony.eviction.bucket.name=5 \
-Ds3.synchrony.eviction.bucket.path=5 \
-Ds3.app.write.provisioned.default=100 \
-Ds3.app.read.provisioned.default=100 \
-Dstatsd.host=localhost \
-Dstatsd.port=8125"
    atl_log "Starting Synchrony"
    ${_RUNJAVA} ${SYNCHRONY_PROPERTIES} synchrony.core sql & >> ${ATL_LOG} 2>&1
    atl_log "Synchrony started successfully"
}

# we have to get Synchrony uber jar from Confluence. So just download and install Confluence without running it
function installConfluence {
    atl_log "Checking if ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} has already been installed"
    if [[ -d "${ATL_CONFLUENCE_INSTALL_DIR}" ]]; then
        local ERROR_MESSAGE="${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} install directory ${ATL_CONFLUENCE_INSTALL_DIR} already exists - aborting installation"
        atl_log "${ERROR_MESSAGE}"
        atl_fatal_error "${ERROR_MESSAGE}"
    fi

    atl_log "Downloading ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} ${ATL_CONFLUENCE_VERSION} from ${ATL_CONFLUENCE_INSTALLER_DOWNLOAD_URL}"
    if ! curl -L -f --silent "${ATL_CONFLUENCE_INSTALLER_DOWNLOAD_URL}" -o "$(atl_tempDir)/installer" >> "${ATL_LOG}" 2>&1
    then
        local ERROR_MESSAGE="Could not download installer from ${ATL_CONFLUENCE_INSTALLER_DOWNLOAD_URL} - aborting installation"
        atl_log "${ERROR_MESSAGE}"
        atl_fatal_error "${ERROR_MESSAGE}"
    fi
    chmod +x "$(atl_tempDir)/installer" >> "${ATL_LOG}" 2>&1
    cat <<EOT >> "$(atl_tempDir)/installer.varfile"
launch.application\$Boolean=false
rmiPort\$Long=8005
app.defaultHome=${ATL_CONFLUENCE_HOME}
app.install.service\$Boolean=true
existingInstallationDir=${ATL_CONFLUENCE_INSTALL_DIR}
sys.confirmedUpdateInstallationString=false
sys.languageId=en
sys.installationDir=${ATL_CONFLUENCE_INSTALL_DIR}
executeLauncherAction\$Boolean=true
httpPort\$Long=8080
portChoice=default
executeLauncherAction\$Boolean=false
EOT

    cp $(atl_tempDir)/installer.varfile /tmp/installer.varfile.bkp

    atl_log "Creating ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} install directory"
    mkdir -p "${ATL_CONFLUENCE_INSTALL_DIR}"

    atl_log "Installing ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} to ${ATL_CONFLUENCE_INSTALL_DIR}"
    "$(atl_tempDir)/installer" -q -varfile "$(atl_tempDir)/installer.varfile" >> "${ATL_LOG}" 2>&1
    atl_log "Installed ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} to ${ATL_CONFLUENCE_INSTALL_DIR}"

    atl_log "Cleaning up"
    rm -rf "$(atl_tempDir)"/installer* >> "${ATL_LOG}" 2>&1

    chown -R "${ATL_CONFLUENCE_USER}":"${ATL_CONFLUENCE_USER}" "${ATL_CONFLUENCE_INSTALL_DIR}"

    atl_log "${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} installation completed"
}

# prepare Confluence Share home link inside Confluence Home folder
function configureSharedHome {
    local CONFLUENCE_SHARED="${ATL_APP_DATA_MOUNT}/${ATL_CONFLUENCE_SERVICE_NAME}/shared-home"
    if mountpoint -q "${ATL_APP_DATA_MOUNT}" || mountpoint -q "${CONFLUENCE_SHARED}"; then
        mkdir -p "${CONFLUENCE_SHARED}"
        chown -R -H "${ATL_CONFLUENCE_USER}":"${ATL_CONFLUENCE_USER}" "${CONFLUENCE_SHARED}" >> "${ATL_LOG}" 2>&1
    else
        atl_log "No mountpoint for shared home exists. Failed to create cluster.properties file."
    fi
}

# prepare Confluence Home
function configureConfluenceHome {
    atl_log "Configuring ${ATL_CONFLUENCE_HOME}"
    mkdir -p "${ATL_CONFLUENCE_HOME}" >> "${ATL_LOG}" 2>&1

    if [[ "x${ATL_CONFLUENCE_DATA_CENTER}" = "xtrue" ]]; then
        configureSharedHome
    fi

    atl_log "Setting ownership of ${ATL_CONFLUENCE_HOME} to '${ATL_CONFLUENCE_USER}' user"
    chown -R -H "${ATL_CONFLUENCE_USER}":"${ATL_CONFLUENCE_USER}" "${ATL_CONFLUENCE_HOME}" >> "${ATL_LOG}" 2>&1
    atl_log "Done configuring ${ATL_CONFLUENCE_HOME}"
}

case "$1" in
    start)
        $1
        ;;
    goSynchrony)
        $1
        ;;
    stop)
        ;;
    *)
        echo "Usage: $0 {start|init-instance-store-dirs|update-host-name}"
        RETVAL=1
esac
exit ${RETVAL}
