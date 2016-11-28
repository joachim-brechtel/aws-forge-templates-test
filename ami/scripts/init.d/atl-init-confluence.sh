#!/bin/bash

set -e

. /etc/init.d/atl-functions

trap 'atl_error ${LINENO}' ERR

ATL_FACTORY_CONFIG=/etc/sysconfig/atl
ATL_USER_CONFIG=/etc/atl

[[ -r "${ATL_FACTORY_CONFIG}" ]] && . "${ATL_FACTORY_CONFIG}"
[[ -r "${ATL_USER_CONFIG}" ]] && . "${ATL_USER_CONFIG}"

if [[ "x${ATL_CONFLUENCE_VERSION}" == "xlatest" ]]; then
    ATL_CONFLUENCE_INSTALLER="atlassian-${ATL_CONFLUENCE_NAME}-linux-x64.bin"
else
    ATL_CONFLUENCE_INSTALLER="atlassian-${ATL_CONFLUENCE_NAME}-${ATL_CONFLUENCE_VERSION}-linux-x64.bin"
fi
ATL_CONFLUENCE_INSTALLER_S3_PATH="${ATL_RELEASE_S3_PATH}/${ATL_JIRA_INSTALLER}"
ATL_CONFLUENCE_INSTALLER_DOWNLOAD_URL="${ATL_CONFLUENCE_INSTALLER_DOWNLOAD_URL:-"https://s3.amazonaws.com/${ATL_RELEASE_S3_BUCKET}/${ATL_CONFLUENCE_INSTALLER_S3_PATH}"}"

ATL_LOG=${ATL_LOG:?"The Atlassian log location must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_APP_DATA_MOUNT=${ATL_APP_DATA_MOUNT:?"The application data mount name must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_INSTANCE_STORE_MOUNT=${ATL_INSTANCE_STORE_MOUNT:?"The instance store mount must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_HOST_NAME=$(atl_hostName)
ATL_HOST_NAME=$(atl_toLowerCase ${ATL_HOST_NAME})

ATL_CONFLUENCE_NAME=${ATL_CONFLUENCE_NAME:?"The CONFLUENCE name must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_CONFLUENCE_SHORT_DISPLAY_NAME=${ATL_CONFLUENCE_SHORT_DISPLAY_NAME:?"The ${ATL_CONFLUENCE_NAME} short display name must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_CONFLUENCE_FULL_DISPLAY_NAME=${ATL_CONFLUENCE_FULL_DISPLAY_NAME:?"The ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} short display name must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_CONFLUENCE_VERSION=${ATL_CONFLUENCE_VERSION:?"The ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} version must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_CONFLUENCE_USER=${ATL_CONFLUENCE_USER:?"The ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} user account must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_CONFLUENCE_DB_NAME=${ATL_CONFLUENCE_DB_NAME:?"The ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} db name must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_CONFLUENCE_DB_USER=${ATL_CONFLUENCE_DB_USER:?"The ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} db user must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_CONFLUENCE_INSTALL_DIR=${ATL_CONFLUENCE_INSTALL_DIR:?"The ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} install dir must be supplied in ${ATL_FACTORY_CONFIG}"}
ATL_CONFLUENCE_HOME=${ATL_CONFLUENCE_HOME:?"The ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} home dir must be supplied in ${ATL_FACTORY_CONFIG}"}

ATL_CONFLUENCE_INSTALLER_DOWNLOAD_URL=${ATL_CONFLUENCE_INSTALLER_DOWNLOAD_URL:?"The ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} installer download URL must be supplied in ${ATL_FACTORY_CONFIG}"}
if [[ "xtrue" == "x$(atl_toLowerCase ${ATL_NGINX_ENABLED})" ]]; then
    ATL_CONFLUENCE_NGINX_PATH=${ATL_CONFLUENCE_NGINX_PATH:?"The ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} home dir must be supplied in ${ATL_FACTORY_CONFIG}"}
fi
ATL_CONFLUENCE_SHARED_HOME="${ATL_CONFLUENCE_HOME}/shared-home"
ATL_CONFLUENCE_SERVICE_NAME="confluence"

function start {
    atl_log "=== BEGIN: service atl-init-confluence start ==="
    atl_log "Initialising ${ATL_CONFLUENCE_FULL_DISPLAY_NAME}"

    installConfluence
    if [[ "xtrue" == "x$(atl_toLowerCase ${ATL_NGINX_ENABLED})" ]]; then
        configureNginx
    elif [[ -n "${ATL_PROXY_NAME}" ]]; then
        updateHostName "${ATL_PROXY_NAME}"
    fi
    configureConfluenceHome
    if [[ "x${ATL_POSTGRES_ENABLED}" == "xtrue" ]]; then
        createConfluenceDbAndRole
    elif [[ -n "${ATL_DB_NAME}" ]]; then
        configureRemoteDb
    fi

    goCONF

    atl_log "=== END:   service atl-init-confluence start ==="
}

function createInstanceStoreDirs {
    atl_log "=== BEGIN: service atl-init-confluence create-instance-store-dirs ==="
    atl_log "Initialising ${ATL_CONFLUENCE_FULL_DISPLAY_NAME}"

    local CONFLUENCE_DIR=${1:?"The instance store directory for ${ATL_CONFLUENCE_NAME} must be supplied"}

    if [[ ! -e "${CONFLUENCE_DIR}" ]]; then
        atl_log "Creating ${CONFLUENCE_DIR}"
        mkdir -p "${CONFLUENCE_DIR}" >> "${ATL_LOG}" 2>&1
    else
        atl_log "Not creating ${CONFLUENCE_DIR} because it already exists"
    fi
    atl_log "Creating ${CONFLUENCE_DIR}/caches"
    mkdir -p "${CONFLUENCE_DIR}/caches" >> "${ATL_LOG}" 2>&1
    atl_log "Creating ${CONFLUENCE_DIR}/tmp"
    mkdir -p "${CONFLUENCE_DIR}/tmp" >> "${ATL_LOG}" 2>&1

    atl_log "Changing ownership of the contents of ${CONFLUENCE_DIR} to ${ATL_CONFLUENCE_USER}"
    chown -R "${ATL_CONFLUENCE_USER}":"${ATL_CONFLUENCE_USER}" "${CONFLUENCE_DIR}"

    atl_log "=== END:   service atl-init-confluence create-instance-store-dirs ==="
}

function configureSharedHome {
    local CONFLUENCE_SHARED="${ATL_APP_DATA_MOUNT}/${ATL_CONFLUENCE_SERVICE_NAME}/shared-home"
    if mountpoint -q "${ATL_APP_DATA_MOUNT}" || mountpoint -q "${CONFLUENCE_SHARED}"; then
        mkdir -p "${CONFLUENCE_SHARED}"
        chown -R -H "${ATL_CONFLUENCE_USER}":"${ATL_CONFLUENCE_USER}" "${CONFLUENCE_SHARED}" >> "${ATL_LOG}" 2>&1 
    else
        atl_log "No mountpoint for shared home exists. Failed to create cluster.properties file."
    fi
}

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

function configureDbProperties {
    atl_log "Configuring ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} DB settings"
    local PRODUCT_CONFIG_NAME="confluence"
    local CONFLUENCE_SETUP_STEP="setupstart"
    local CONFLUENCE_SETUP_TYPE="custom"
    local CONFLUENCE_BUILD_NUMBER="0"
    cat <<EOT | su "${ATL_CONFLUENCE_USER}" -c "tee -a \"${ATL_CONFLUENCE_HOME}/confluence.cfg.xml\"" > /dev/null
<?xml version="1.0" encoding="UTF-8"?>

<${PRODUCT_CONFIG_NAME}-configuration>
  <setupStep>${CONFLUENCE_SETUP_STEP}</setupStep>
  <setupType>${CONFLUENCE_SETUP_TYPE}</setupType>
  <buildNumber>${CONFLUENCE_BUILD_NUMBER}</buildNumber>
  <properties>
    <property name="confluence.database.choice">postgresql</property>
    <property name="confluence.database.connection.type">database-type-standard</property>
    <property name="hibernate.connection.driver_class">${ATL_JDBC_DRIVER}</property>
    <property name="hibernate.connection.url">${ATL_JDBC_URL}</property>
    <property name="hibernate.connection.password">${ATL_JDBC_PASSWORD}</property>
    <property name="hibernate.connection.username">${ATL_JDBC_USER}</property>
    <property name="hibernate.dialect">defa</property>
EOT

    if [[ "x${ATL_CONFLUENCE_DATA_CENTER}" = "xtrue" ]]; then
        cat <<EOT | su "${ATL_CONFLUENCE_USER}" -c "tee -a \"${ATL_CONFLUENCE_HOME}/confluence.cfg.xml\"" > /dev/null
    <property name="confluence.cluster">true</property>
    <property name="shared-home">${ATL_CONFLUENCE_SHARED_HOME}</property>
    <property name="confluence.cluster.home">${ATL_CONFLUENCE_SHARED_HOME}</property>
    <property name="confluence.cluster.aws.ami.role">${ATL_HAZELCAST_NETWORK_AWS_IAM_ROLE}</property>
    <property name="confluence.cluster.aws.region">${ATL_HAZELCAST_NETWORK_AWS_IAM_REGION}</property>
    <property name="confluence.cluster.aws.host.header">ec2.amazonaws.com</property>
    <property name="confluence.cluster.aws.security.group.name">${ATL_HAZELCAST_GROUP_NAME}</property>
    <property name="confluence.cluster.aws.tag.key">${ATL_HAZELCAST_NETWORK_AWS_TAG_KEY}</property>
    <property name="confluence.cluster.aws.tag.value">${ATL_HAZELCAST_NETWORK_AWS_TAG_VALUE}</property>
    <property name="confluence.cluster.join.type">aws</property>
    <property name="confluence.cluster.name">${ATL_AWS_STACK_NAME}</property>
    <property name="confluence.cluster.ttl">1</property>
EOT
    fi
    appendExternalConfigs
     cat <<EOT | su "${ATL_CONFLUENCE_USER}" -c "tee -a \"${ATL_CONFLUENCE_HOME}/confluence.cfg.xml\"" > /dev/null
  </properties>
</${PRODUCT_CONFIG_NAME}-configuration>
EOT

    su "${ATL_CONFLUENCE_USER}" -c "chmod 600 \"${ATL_CONFLUENCE_HOME}/confluence.cfg.xml\"" >> "${ATL_LOG}" 2>&1
    atl_log "Done configuring ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} to use the ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} DB role ${ATL_CONFLUENCE_DB_USER}"
}

function appendExternalConfigs {
    if [[ -n "${ATL_CONFLUENCE_PROPERTIES}" ]]; then
        declare -a PROP_ARR
        readarray -t PROP_ARR <<<"${ATL_CONFLUENCE_PROPERTIES}"
        for prop in PROP_ARR; do
            su "${ATL_BITBUCKET_USER}" -c "echo \"${prop}\" >> "${ATL_CONFLUENCE_HOME}/confluence.cfg.xml\" >> "${ATL_LOG}" 2>&1
        done
    fi
}

function createConfluenceDbAndRole {
    if atl_roleExists ${ATL_CONFLUENCE_DB_USER}; then
        atl_log "${ATL_CONFLUENCE_DB_USER} role already exists. Skipping database and role creation. Skipping dbconfig.xml update"
    else
        local PASSWORD=$(cat /proc/sys/kernel/random/uuid)

        atl_createRole "${ATL_CONFLUENCE_SHORT_DISPLAY_NAME}" "${ATL_CONFLUENCE_DB_USER}" "${PASSWORD}"
        atl_createDb "${ATL_CONFLUENCE_SHORT_DISPLAY_NAME}" "${ATL_CONFLUENCE_DB_NAME}" "${ATL_CONFLUENCE_DB_USER}"
        configureDbProperties "org.postgresql.Driver" "jdbc:postgresql://localhost/${ATL_CONFLUENCE_DB_NAME}" "${ATL_CONFLUENCE_DB_USER}" "${PASSWORD}"
    fi
}

function configureRemoteDb {
    atl_log "Configuring remote DB for use with ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME}"

    if [[ -n "${ATL_DB_PASSWORD}" ]]; then
        atl_configureDbPassword "${ATL_DB_PASSWORD}" "*" "${ATL_DB_HOST}" "${ATL_DB_PORT}"
        
        if atl_roleExists ${ATL_JDBC_USER} "postgres" ${ATL_DB_HOST} ${ATL_DB_PORT}; then
            atl_log "${ATL_JDBC_USER} role already exists. Skipping role creation."
        else
            atl_createRole "${ATL_CONFLUENCE_SHORT_DISPLAY_NAME}" "${ATL_JDBC_USER}" "${ATL_JDBC_PASSWORD}" "${ATL_DB_HOST}" "${ATL_DB_PORT}"
            atl_createRemoteDb "${ATL_CONFLUENCE_SHORT_DISPLAY_NAME}" "${ATL_DB_NAME}" "${ATL_JDBC_USER}" "${ATL_DB_HOST}" "${ATL_DB_PORT}" "C" "C" "template0"
        fi

        configureDbProperties "${ATL_JDBC_DRIVER}" "${ATL_JDBC_URL}" "${ATL_JDBC_USER}" "${ATL_JDBC_PASSWORD}"
    fi
}

function configureNginx {
    updateHostName "${ATL_HOST_NAME}"
    atl_addNginxProductMapping "${ATL_CONFLUENCE_NGINX_PATH}" 8080
}

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

function noCONF {
    atl_log "Stopping ${ATL_CONFLUENCE_SERVICE_NAME} service"
    service "${ATL_CONFLUENCE_SERVICE_NAME}" stop >> "${ATL_LOG}" 2>&1
}

function goCONF {
    atl_log "Starting ${ATL_CONFLUENCE_SERVICE_NAME} service"
    service "${ATL_CONFLUENCE_SERVICE_NAME}" start >> "${ATL_LOG}" 2>&1
}

function updateHostName {
    atl_configureTomcatConnector "${1}" "8080" "8081" "${ATL_CONFLUENCE_USER}" \
        "${ATL_CONFLUENCE_INSTALL_DIR}/conf" \
        "${ATL_CONFLUENCE_INSTALL_DIR}/confluence/WEB-INF"

    STATUS="$(service "${ATL_CONFLUENCE_SERVICE_NAME}" status || true)"
    if [[ "${STATUS}" =~ .*\ is\ running ]]; then
        atl_log "Restarting ${ATL_CONFLUENCE_SHORT_DISPLAY_NAME} to pick up host name change"
        noCONF
        goCONF
    fi
}

case "$1" in
    start)
        $1
        ;;
    create-instance-store-dirs)
        createInstanceStoreDirs $2
        ;;
    update-host-name)
        updateHostName $2
        ;;
    stop)
        ;;
    *)
        echo "Usage: $0 {start|init-instance-store-dirs|update-host-name}"
        RETVAL=1
esac
exit ${RETVAL}

