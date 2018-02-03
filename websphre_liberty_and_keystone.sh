#!/bin/bash

## Install all the libraries needed
sudo apt-get update
# websphere
sudo apt-get install -y openjdk-7-jre-headless
# mod_auth_oidc
sudo apt-get install -y libjansson4 libhiredis0.10 libcurl3 apache2
# generally useful
sudo apt-get install -y python-pip git curl vim

### Configure WebSphere Liberty

# download + install websphere liberty
wget https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/8.5.5.5/wlp-runtime-8.5.5.5.jar
wget https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/downloads/wlp/8.5.5.5/wlp-extended-8.5.5.5.jar
java -jar wlp-runtime-8.5.5.5.jar --acceptLicense .
java -jar wlp-extended-8.5.5.5.jar --acceptLicense .
./wlp/bin/featureManager install openidConnectServer-1.0 --when-file-exists=ignore --acceptLicense

# create a new server
./wlp/bin/server create oauthServer

# configure the server
rm ./wlp/usr/servers/oauthServer/server.xml
cat >> ./wlp/usr/servers/oauthServer/server.xml << EOF
<server>
    <featureManager>
        <feature>openidConnectServer-1.0</feature>
        <feature>ssl-1.0</feature>
        <feature>appSecurity-2.0</feature>
        <feature>servlet-3.0</feature>
    </featureManager>

    <ldapRegistry id="bluepages" realm="w3" host="bluepages.ibm.com" port="389" 
                ignoreCase="true" baseDN="o=ibm.com" ldapType="IBM Tivoli Directory Server" >
        <idsFilters
                 userFilter="(&amp;(emailAddress=%v)(objectclass=person))"
                 groupFilter="(&amp;(cn=%v)(objectclass=groupOfUniqueNames))"
                 userIdMap="*:emailAddress"
                 groupIdMap="*:cn"
                 groupMemberIdMap="groupOfUniqueNames:uniquemember" />
    </ldapRegistry>

    <keyStore id="defaultKeyStore" password="insecurePass"/>

    <httpEndpoint host="localhost" httpPort="9080" httpsPort="9443" id="defaultHttpEndpoint"/>

    <oauth-roles>
        <authenticated>
            <special-subject type="ALL_AUTHENTICATED_USERS" />
        </authenticated>
    </oauth-roles>

    <openidConnectProvider id="OP" oauthProviderRef="Oauth" />

    <oauthProvider id="Oauth" >
        <localStore>
            <client name="rp" secret="LDo8LTor"
                displayname="rp"
                introspectTokens="true"
                redirect="https://localhost:8020/oauthclient/redirect.jsp"
                scope="openid profile email phone address"
                preAuthorizedScope="openid profile"
                enabled="true"/>
        </localStore>
    </oauthProvider>
</server>
EOF

# start the server
./wlp/bin/server start oauthServer

### Configure Keystone and OpenStack

# install the OpenID Connect apache module
wget https://github.com/pingidentity/mod_auth_openidc/releases/download/v1.8.3/libapache2-mod-auth-openidc_1.8.3-1_amd64.deb
sudo dpkg -i libapache2-mod-auth-openidc_1.8.3-1_amd64.deb

# download and install OpenStack
git clone https://github.com/openstack-dev/devstack
cd devstack
cat >> localrc << EOF
RECLONE=yes
ENABLED_SERVICES=key,g-api,g-reg,n-api,n-crt,n-obj,n-cpu,n-net,n-cond,cinder,c-sch,c-api,c-vol,n-sch,n-cauth,horizon,mysql,rabbit
SERVICE_TOKEN=openstack
ADMIN_PASSWORD=openstack
MYSQL_PASSWORD=openstack
RABBIT_PASSWORD=openstack
SERVICE_PASSWORD=openstack
LOGFILE=/opt/stack/logs/stack.sh.log
LIBS_FROM_GIT=python-keystoneclient,python-openstackclient
EOF
./stack.sh

# add federation options, under [auth] and [federation] to keystone.conf
sed -i "s/#methods = external,password,token,oauth1/methods = external,password,token,oidc/g" /etc/keystone/keystone.conf
sed -i "s/#oauth1 = keystone.auth.plugins.oauth1.OAuth/oidc = keystone.auth.plugins.mapped.Mapped/g" /etc/keystone/keystone.conf
sed -i "s/#remote_id_attribute = <None>/remote_id_attribute = HTTP_OIDC_ISS/g" /etc/keystone/keystone.conf
sed -i "s/#trusted_dashboard =/trusted_dashboard = http:\/\/$fqdn/g" /etc/keystone/keystone.conf

# export environment variables for bootstapping
export OS_IDENTITY_API_VERSION=3
export OS_PASSWORD=openstack
export OS_AUTH_URL=http://localhost:5000/v3
export OS_USERNAME=admin
export OS_TENANT_NAME=admin
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_DOMAIN_ID=default

# create a group for federated users, assign the group a role on a project
group_id=`openstack group create federated_users -f value -c id`
openstack role add member --group federated_users --project demo

# create mapping JSON + idp, mapping, protocol
rm -rf mapping.ibm.json
cat >> mapping.ibm.json << EOF
[
    {
        "local": [
            {
                "group": {
                    "id": "replace_group_id"
                }
            }
        ],
        "remote": [
            {
                "type": "HTTP_OIDC_GROUPIDS",
                "any_one_of": [
                    "cn=IBM_Canada_Lab*"
                ],
                "regex": true
            }
        ]
    }
]
EOF
sed -i "s/replace_group_id/$group_id/g" mapping.ibm.json

# Add remote ids to keystone conf
openstack identity provider create bluepages --remote-id bluepages
openstack mapping create ibm_mapping --rules mapping.ibm.json
openstack federation protocol create oidc --identity-provider bluepages --mapping ibm_mapping

# configure the apache config file
sudo rm -rf /etc/apache2/sites-available/keystone.conf
cat >> apache_config.conf << EOF
LoadModule auth_openidc_module /usr/lib/apache2/modules/mod_auth_openidc.so
Listen 5000
Listen 35357
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\" %D(us)" keystone_combined

<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=steve display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /var/www/keystone/main
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log keystone_combined

    SetEnv HTTP_OIDC_ISS bluepages

    OIDCOAuthIntrospectionEndpoint https://localhost:9443/oidc/endpoint/OP/introspect
    OIDCOAuthIntrospectionTokenParamName token
    OIDCOAuthRemoteUserClaim sub
    OIDCOAuthClientID rp
    OIDCOAuthClientSecret LDo8LTor
    OIDCOAuthSSLValidateServer Off
    OIDCClaimDelimiter ";"
    OIDCClaimPrefix "OIDC-"

    <LocationMatch "/v3/OS-FEDERATION/identity_providers/bluepages/protocols/oidc/.*?">
      Authtype oauth20
      Require valid-user
      LogLevel debug
    </LocationMatch>

</VirtualHost>

<VirtualHost *:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=steve display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /var/www/keystone/admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log keystone_combined
</VirtualHost>
EOF
sudo mv apache_config.conf /etc/apache2/sites-available/keystone.conf

# restart apache
sudo service apache2 restart

# unset env vars
unset OS_IDENTITY_API_VERSION
unset OS_PASSWORD
unset OS_AUTH_URL
unset OS_USERNAME
unset OS_TENANT_NAME
unset OS_USER_DOMAIN_ID
unset OS_PROJECT_DOMAIN_ID

# test things out:
openstack federation project list --os-auth-url http://10.0.2.15:5000/v3 --os-auth-type v3oidc --os-identity-provider bluepages --os-protocol oidc --os-username stevemar@ca.ibm.com --os-password $password$ --os-client-id rp --os-client-secret LDo8LTor --os-access-token-endpoint https://localhost:9443/oidc/endpoint/OP/token --os-identity-api-version 3 --insecure
