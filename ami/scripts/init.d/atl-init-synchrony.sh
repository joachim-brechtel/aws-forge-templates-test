#!/bin/bash

set -e

# in a case of "test", we just need to load functions into the testing context
if ! [ "$1" == "test" ]; then

. /etc/init.d/atl-functions
. /etc/init.d/atl-confluence-common

trap 'atl_error ${LINENO}' ERR

ATL_SYNCHRONY_STACK_SPACE=${ATL_SYNCHRONY_STACK_SPACE:?"The Stack Space of Synchrony must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_SYNCHRONY_MEMORY=${ATL_SYNCHRONY_MEMORY:?"The Memory of Synchrony must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_SYNCHRONY_WAITING_CONFIG_TIME=${ATL_SYNCHRONY_WAITING_CONFIG_TIME:?"The time waiting for Synchrony configuration must be supplied in ${ATL_FACTORY_CONFIG}"}

ATL_SYNCHRONY_SERVICE_NAME="synchrony"
ATL_CONFLUENCE_SHARED_CONFIG_FILE="${ATL_CONFLUENCE_SHARED_HOME}/confluence.cfg.xml"
ATL_CONFLUENCE_JRE_HOME="${ATL_CONFLUENCE_INSTALL_DIR}/jre/bin"
ATL_SYNCHRONY_JAR_PATH="${ATL_CONFLUENCE_INSTALL_DIR}/confluence/WEB-INF/packages/synchrony-standalone.jar"
# find the fisrt postgres driver in lib folder
ATL_POSTGRES_DRIVER_PATH=$(ls -t ${ATL_CONFLUENCE_INSTALL_DIR}/confluence/WEB-INF/lib/postgresql*.jar | head -n 1)
SYNCHRONY_JWT_PRIVATE_KEY=""
SYNCHRONY_JWT_PUBLIC_KEY=""
SYNCHRONY_PID="${ATL_CONFLUENCE_HOME}/synchrony.pid"

_RUNJAVA="${ATL_CONFLUENCE_JRE_HOME}/java"
SYNCHRONY_CLASSPATH="${ATL_SYNCHRONY_JAR_PATH}:${ATL_POSTGRES_DRIVER_PATH}"
AWS_EC2_PRIVATE_IP=$(curl -f --silent http://169.254.169.254/latest/meta-data/local-ipv4 || echo "")

fi

# main method of this service
function start {
    atl_log "=== BEGIN: service atl-init-synchrony start ==="
    atl_log "Initialising Synchrony for ${ATL_CONFLUENCE_FULL_DISPLAY_NAME}"
    if installConfluence; then
        configureConfluenceHome;
        exportCatalinaOpts;
        # Need to reset those variables because it contains wrong value before we install Confluence
        ATL_POSTGRES_DRIVER_PATH=$(ls -t ${ATL_CONFLUENCE_INSTALL_DIR}/confluence/WEB-INF/lib/postgresql*.jar | head -n 1)
        SYNCHRONY_CLASSPATH="${ATL_SYNCHRONY_JAR_PATH}:${ATL_POSTGRES_DRIVER_PATH}"
    else
        atl_log "Skip install Confluence...And start Synchrony straight away"
    fi

    # re-enable atl-init-40-products as we want it will help to start Synchrony when restarting
    sudo chkconfig --add "atl-init-40-products"
    sudo chkconfig "atl-init-40-products" on
    startSynchrony
    atl_log "=== END:   service atl-init-synchrony start ==="
}

function stop() {
    stopSynchrony
}

# Synchrony requires JWT keys to communicate with Confluence application. These keys are written to the config file
# after admin will go through the setup and provide license. This function waits for the keys being available in the
# config file.
function waitForConfluenceConfigInSharedHome() {
    atl_log "=== BEGIN: Waiting for confluence.cfg.xml available in shared home folder ==="
    while [[ ! -f ${ATL_CONFLUENCE_SHARED_CONFIG_FILE} ]]; do
	sleep ${ATL_SYNCHRONY_WAITING_CONFIG_TIME}
	atl_log "====== :   Keep waiting for ${ATL_SYNCHRONY_WAITING_CONFIG_TIME} seconds ======"
    done

    atl_log "====== : Fetching JWT keys from Confluence config... ======"
    while [[ -z ${SYNCHRONY_JWT_PRIVATE_KEY} || -z ${SYNCHRONY_JWT_PUBLIC_KEY} ]]; do
    	SYNCHRONY_JWT_PRIVATE_KEY=$(extractJWTKeyFromConfluenceConfig 'jwt.private.key') >> ${ATL_LOG} 2>&1
        SYNCHRONY_JWT_PUBLIC_KEY=$(extractJWTKeyFromConfluenceConfig 'jwt.public.key') >> ${ATL_LOG} 2>&1
        if [[ -z ${SYNCHRONY_JWT_PRIVATE_KEY} || -z ${SYNCHRONY_JWT_PUBLIC_KEY} ]]; then
	    atl_log "====== :   Could not load value for JWT key; will wait for next ${ATL_SYNCHRONY_WAITING_CONFIG_TIME} seconds before reload ======"
	    sleep ${ATL_SYNCHRONY_WAITING_CONFIG_TIME}
        fi
    done

    atl_log "=== END: Waiting for confluence.cfg.xml available in shared home folder ==="
}

# To support retries these commands won't fail the script by virtue of using `--shell` option for xmllint.
function extractJWTKeyFromConfluenceConfig {
    local keyType=$1
    if [[ "${keyType}" != "jwt.private.key" && "${keyType}" != "jwt.public.key" ]]; then
        atl_log "Unexpected value for keyType - ${keyType} to extract JWT key from confluence.cfg.xml"
        exit 1
    fi
    echo "cat //properties/property[@name='${keyType}']/text()" | xmllint --nocdata --shell ${ATL_CONFLUENCE_SHARED_CONFIG_FILE} | sed '1d;$d'
}

function parseSemVersion {
    echo "$1" | sed 's/[^0-9.]*\([0-9.]*\).*/\1/'
}

function majorVersion {
    echo "$1" | awk -F \. '{print $1}'
}

function minorVersion {
    echo "$1" | awk -F \. '{print $2}'
}

function patchVersion {
    echo "$1" | awk -F \. '{print $3}'
}

# Function compares 2 sem versions
# param $1 - first version to compare (semver format, can be prefixed or suffixed, like "confluence-paret-6.5.0-m01")
# param $2 - second version to compare (semver format, can be prefixed or suffixed, like "confluence-paret-6.5.0-m01")
# return negative, if version1 < version2, positive, if version1 > version2 and 0, if versions are equal
function compareVersions {
    local version1=$(parseSemVersion $1)
    local version2=$(parseSemVersion $2)
    local diff=$(( $(majorVersion $version1)-$(majorVersion $version2) ))
    if [ $diff -eq 0 ]; then
        diff=$(( $(minorVersion $version1)-$(minorVersion $version2) ))
        if [ $diff -eq 0 ]; then
            diff=$(( $(patchVersion $version1)-$(patchVersion $version2) ))
        fi
    fi
    echo $diff
}

function oldSynchronyStartupProperties {
    echo "\
${ATL_SYNCHRONY_STACK_SPACE} ${ATL_SYNCHRONY_MEMORY} \
-classpath ${SYNCHRONY_CLASSPATH} \
-Dreza.cluster.impl=hazelcast-micros \
-Dreza.database.url=${ATL_JDBC_URL} \
-Dreza.database.username=${ATL_JDBC_USER} \
-Dreza.database.password=${ATL_JDBC_PASSWORD} \
-Dreza.bind=${AWS_EC2_PRIVATE_IP} \
-Dreza.cluster.bind=${AWS_EC2_PRIVATE_IP} \
-Dcluster.interfaces=${AWS_EC2_PRIVATE_IP} \
-Dreza.cluster.base.port=25500 \
-Dreza.cluster.bind=${AWS_EC2_PRIVATE_IP} \
-Dreza.service.url=${ATL_SYNCHRONY_SERVICE_URL} \
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
-Ddynamo.events2.table.name=5 \
-Ddynamo.snapshots2.table.name=5 \
-Ddynamo.chunks.table.name=5 \
-Ddynamo.limits.table.name=5 \
-Dredis.kv.cache2.host=5 \
-Dredis.kv.cache2.port=5 \
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
}

function newSynchronyStartupProperties {
    echo "\
${ATL_SYNCHRONY_STACK_SPACE} ${ATL_SYNCHRONY_MEMORY} \
-classpath ${SYNCHRONY_CLASSPATH} \
-Dsynchrony.cluster.impl=hazelcast-btf \
-Dsynchrony.database.url=${ATL_JDBC_URL} \
-Dsynchrony.database.username=${ATL_JDBC_USER} \
-Dsynchrony.database.password=${ATL_JDBC_PASSWORD} \
-Dsynchrony.database.idle.connection.test.period=${ATL_SYNCHRONY_DATABASE_IDLE_CONNECTION_TEST_PERIOD} \
-Dsynchrony.database.max.idle.time=${ATL_SYNCHRONY_DATABASE_MAX_IDLE_TIME} \
-Dsynchrony.database.max.idle.time.excess.connections=${ATL_SYNCHRONY_DATABASE_MAX_IDLE_TIME_EXCESS_CONNECTIONS} \
-Dsynchrony.database.test.connection.on.checkin=${ATL_SYNCHRONY_DATABASE_TEST_CONNECTION_ON_CHECKIN} \
-Dsynchrony.bind=${AWS_EC2_PRIVATE_IP} \
-Dsynchrony.cluster.bind=${AWS_EC2_PRIVATE_IP} \
-Dcluster.interfaces=${AWS_EC2_PRIVATE_IP} \
-Dsynchrony.cluster.base.port=25500 \
-Dsynchrony.service.url=${ATL_SYNCHRONY_SERVICE_URL} \
-Dsynchrony.context.path=/synchrony \
-Dsynchrony.port=8091 \
-Dcluster.name=Synchrony-Cluster \
-Dcluster.join.type=aws \
-Dcluster.join.aws.tag.key=${ATL_HAZELCAST_NETWORK_AWS_TAG_KEY} \
-Dcluster.join.aws.tag.value=${ATL_HAZELCAST_NETWORK_AWS_TAG_VALUE} \
-Dcluster.join.aws.region=${ATL_HAZELCAST_NETWORK_AWS_IAM_REGION} \
-Djwt.private.key=${SYNCHRONY_JWT_PRIVATE_KEY} \
-Djwt.public.key=${SYNCHRONY_JWT_PUBLIC_KEY}"
}

function getSynchronyStartupProperties {
    if [ "x$1" == "xlatest" ] || [ $(compareVersions "$1" "6.5.0") -gt -1 ]; then
        newSynchronyStartupProperties
    else
        oldSynchronyStartupProperties
    fi
}

# start Synchrony service
function startSynchrony {
    atl_log "Starting ${ATL_SYNCHRONY_SERVICE_NAME} service"
    waitForConfluenceConfigInSharedHome
    SYNCHRONY_PROPERTIES=$(getSynchronyStartupProperties "${ATL_CONFLUENCE_VERSION}")
    atl_log "Starting Synchrony"

    # make sure we don't start Synchrony if there is a running process there
    if [ ! -z ${SYNCHRONY_PID} ]; then
        if [ ! -f ${SYNCHRONY_PID} ]; then
            if [ -s "$SYNCHRONY_PID" ]; then
                atl_log "Existing Synchrony process ID found"
                if [ -r "$CATALINA_PID" ]; then
                    PID=`cat "$CATALINA_PID"`
                    ps -p $PID >/dev/null 2>&1
                    if [ $? -eq 0 ] ; then
                        atl_log "Synchrony appears to still be running with PID $PID. Start aborted."
                        atl_log "If the following process is not a Synchrony process, remove the PID file and try again:"
                        ps -f -p $PID
                        exit 1
                    else
                        atl_log "Please remove ${SYNCHRONY_PID} and try to start Synchrony again"
                        exit 1
                    fi
                else
                    atl_log "Unable to read PID file ${SYNCHRONY_PID}. Start aborted."
                    exit 1
                fi
            fi
        fi
    fi

    (${_RUNJAVA} ${SYNCHRONY_PROPERTIES} synchrony.core sql & ) >> ${ATL_LOG} 2>&1
    echo $! > ${SYNCHRONY_PID}
    atl_log "Synchrony started successfully"
}

function stopSynchrony() {
    atl_log "Stopping ${ATL_SYNCHRONY_SERVICE_NAME} service"
    SLEEP=10
    if [ ! -z "$SYNCHRONY_PID" ]; then
        if [ -f "$SYNCHRONY_PID" ]; then
            while [ $SLEEP -ge 0 ]; do
                kill -0 `cat "$SYNCHRONY_PID"` >/dev/null 2>&1
                if [ $? -gt 0 ]; then
                    rm -f "$SYNCHRONY_PID" >/dev/null 2>&1
                    if [ $? != 0 ]; then
                        atl_log "The PID file could not be removed or cleared."
                    fi
                    atl_log "${ATL_SYNCHRONY_SERVICE_NAME} stopped."
                    break
                fi
                if [ $SLEEP -gt 0 ]; then
                    sleep 1
                fi
                if [ $SLEEP -eq 0 ]; then
                    atl_log "${ATL_SYNCHRONY_SERVICE_NAME} did not stop in time."
                    rm -f "$SYNCHRONY_PID" >/dev/null 2>&1
                    kill -3 `cat "$CATALINA_PID"`
                    if [ $? != 0 ]; then
                        atl_log "The ${ATL_SYNCHRONY_SERVICE_NAME} service could not be stopped"
                    fi
                fi
                SLEEP=`expr $SLEEP - 1 `
            done
        fi
    fi
    atl_log "Synchrony stopped successfully"
}

# we have to get Synchrony uber jar from Confluence. So just download and install Confluence without running it
function installConfluence {
    atl_log "Checking if ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} has already been installed"

    if [ "true" = "${ATL_USE_COLLECTD}" ] && [ -e /etc/init.d/collectd ]; then
        atl_log "Creating file /etc/ld.so.conf.d/confluence.conf"
        echo /usr/lib/jvm/jre-1.7.0-openjdk.x86_64/lib/amd64/server/ > /etc/ld.so.conf.d/confluence.conf
        sudo ldconfig
        if [ -n $ATL_STARTCOLLECTD == "true" ]; then
            service collectd restart
        fi
        atl_log "Creating file /etc/ld.so.conf.d/confluence.conf ==> done"
    fi

    if [[ -d "${ATL_CONFLUENCE_INSTALL_DIR}" ]]; then
        local ERROR_MESSAGE="${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} install directory ${ATL_CONFLUENCE_INSTALL_DIR} already exists - aborting installation"
        atl_log "${ERROR_MESSAGE}"
        return 1
    fi

    atl_log "Downloading ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} ${ATL_CONFLUENCE_VERSION} from ${ATL_CONFLUENCE_INSTALLER_DOWNLOAD_URL}"
    if ! curl -L -f --silent "${ATL_CONFLUENCE_INSTALLER_DOWNLOAD_URL}" -o "$(atl_tempDir)/installer" >> "${ATL_LOG}" 2>&1 ; then
        local ERROR_MESSAGE="Could not download installer from ${ATL_CONFLUENCE_INSTALLER_DOWNLOAD_URL} - aborting installation"
        atl_log "${ERROR_MESSAGE}"
        atl_fatal_error "${ERROR_MESSAGE}"
    fi
    chmod +x "$(atl_tempDir)/installer" >> "${ATL_LOG}" 2>&1
    cat <<EOT >> "$(atl_tempDir)/installer.varfile"
app.defaultHome=${ATL_CONFLUENCE_HOME}
app.install.service\$Boolean=false
executeLauncherAction\$Boolean=false
executeLauncherAction\$Boolean=true
existingInstallationDir=${ATL_CONFLUENCE_INSTALL_DIR}
httpPort\$Long=8080
launch.application\$Boolean=false
portChoice=default
rmiPort\$Long=8005
sys.confirmedUpdateInstallationString=false
sys.installationDir=${ATL_CONFLUENCE_INSTALL_DIR}
sys.languageId=en
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
    return 0
}

# prepare Confluence Share home link inside Confluence Home folder
function configureSharedHome {
    atl_log "=== BEGIN: service atl-init-confluence configureSharedHome ==="
    local CONFLUENCE_SHARED="${ATL_APP_DATA_MOUNT}/${ATL_CONFLUENCE_SERVICE_NAME}/shared-home"
    if mountpoint -q "${ATL_APP_DATA_MOUNT}" || mountpoint -q "${CONFLUENCE_SHARED}"; then
        mkdir -p "${CONFLUENCE_SHARED}"
        chown -H "${ATL_CONFLUENCE_USER}":"${ATL_CONFLUENCE_USER}" "${CONFLUENCE_SHARED}" >> "${ATL_LOG}" 2>&1
        if ! chown -H "${ATL_CONFLUENCE_USER}":"${ATL_CONFLUENCE_USER}" ${CONFLUENCE_SHARED}/* >> "${ATL_LOG}" 2>&1; then
            atl_log "Chown on contents of shared home failed most likley because this is a new cluster and no contents yet exist, moving on"
        fi
        su "${ATL_CONFLUENCE_USER}" -c "ln -s \"${CONFLUENCE_SHARED}\" \"${ATL_CONFLUENCE_SHARED_HOME}\"" >> "${ATL_LOG}" 2>&1
    else
        atl_log "No mountpoint for shared home exists."
    fi
    atl_log "=== END:   service atl-init-confluence configureSharedHome ==="
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
    startSynchrony)
        $1
        ;;
    stop)
        $1
        ;;
    test)
        RETVAL=0
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        RETVAL=1
esac

# in a case of "test", we just need to load functions into the testing context, and prevent exiting the testing script
if ! [ "$1" == "test" ]; then
    exit ${RETVAL}
fi
