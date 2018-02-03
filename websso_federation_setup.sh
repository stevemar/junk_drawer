# DO NOT USE THIS, IT IS VERY OLD!

#!/bin/bash

fqdn=sso-demo.test.ibmcloud.com
user=ibmcloud

# Install the OpenID Connect apache module
# not necessary, but will resolve any config errors when installing the module
sudo apt-get install libjansson4 libhiredis0.10 libcurl3 -y
sudo apt-get install -f -y
# TODO: figure out why v1.8.4 and 1.8.5 won't install
wget https://github.com/pingidentity/mod_auth_openidc/releases/download/v1.8.3/libapache2-mod-auth-openidc_1.8.3-1_amd64.deb
sudo dpkg -i libapache2-mod-auth-openidc_1.8.3-1_amd64.deb

# Setup OpenStack
sudo apt-get install python-pip git curl vim -y
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

# Add Federation options, under [auth] and [federation] to keystone.conf
sed -i "s/#methods = external,password,token,oauth1/methods = external,password,token,oidc/g" /etc/keystone/keystone.conf
sed -i "s/#oauth1 = keystone.auth.plugins.oauth1.OAuth/oidc = keystone.auth.plugins.mapped.Mapped/g" /etc/keystone/keystone.conf
sed -i "s/#remote_id_attribute = <None>/remote_id_attribute = HTTP_OIDC_ISS/g" /etc/keystone/keystone.conf
sed -i "s/#trusted_dashboard =/trusted_dashboard = http:\/\/$fqdn/g" /etc/keystone/keystone.conf

# Export environment variables
export OS_IDENTITY_API_VERSION=3
export OS_PASSWORD=openstack
export OS_AUTH_URL=http://localhost:5000/v3
export OS_USERNAME=admin
export OS_TENANT_NAME=admin
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_DOMAIN_ID=default

# Create a group for federated users, assign the group a role on a project
group_id=`openstack group create developers -f value -c id`
openstack role add member --group developers --project demo

# Download mapping JSON and create idp, mapping, protocol
rm -rf mapping.google.json
cat >> mapping.google.json << EOF
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
                "type": "HTTP_OIDC_ISS",
                "any_one_of": [
                    "https://accounts.google.com"
                ]
            }
        ]
    }
]
EOF
sed -i "s/replace_group_id/$group_id/g" mapping.google.json
# Add remote ids to keystone conf
openstack identity provider create google --remote-id https://accounts.google.com
openstack mapping create google_mapping --rules mapping.google.json
openstack federation protocol create oidc --identity-provider google --mapping google_mapping

# Download the Apache config file
sudo rm -rf /etc/apache2/sites-available/keystone.conf
cat >> apache_config.conf << EOF
LoadModule auth_openidc_module /usr/lib/apache2/modules/mod_auth_openidc.so
Listen 5000
Listen 35357
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\" %D(us)" keystone_combined
 
<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=replace_user display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /var/www/keystone/main
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log keystone_combined
 
    OIDCClaimPrefix "OIDC-"
    OIDCResponseType "id_token"
    OIDCScope "openid email profile"
    OIDCProviderMetadataURL https://accounts.google.com/.well-known/openid-configuration
    OIDCClientID 78026256901-9oice6ionj19voicnrii2lfl86a1i4rp.apps.googleusercontent.com
    OIDCClientSecret d6TiBYA3qQUuzlR91Q-YzpJA
    OIDCCryptoPassphrase openstack
    OIDCRedirectURI http://replace_fqdn:5000/v3/auth/OS-FEDERATION/websso/oidc/redirect
 
    <Location ~ "/v3/auth/OS-FEDERATION/websso/oidc">
      AuthType openid-connect
      Require valid-user
      LogLevel debug
    </Location>
</VirtualHost>
 
<VirtualHost *:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=replace_user display-name=%{GROUP}
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
sed -i "s/replace_user/$user/g" apache_config.conf
sed -i "s/replace_fqdn/$fqdn/g" apache_config.conf
sudo mv apache_config.conf /etc/apache2/sites-available/keystone.conf

# Move template file to /etc/keystone
cp /opt/stack/keystone/etc/sso_callback_template.html /etc/keystone/

# Setup WebSSO values for Horizon
## This probably shouldn't be localhost, but a public ip address
sed -i "s/^OPENSTACK_KEYSTONE_URL=.*/OPENSTACK_KEYSTONE_URL = \"http:\/\/$fqdn:5000\/v3\"/g" /opt/stack/horizon/openstack_dashboard/local/local_settings.py
cat >> /opt/stack/horizon/openstack_dashboard/local/local_settings.py << EOF
OPENSTACK_API_VERSIONS = {
     "identity": 3
}

WEBSSO_ENABLED = True
WEBSSO_CHOICES = (
  ("credentials", _("Keystone Credentials")),
  ("oidc", _("OpenID Connect"))
)

WEBSSO_INITIAL_CHOICE = "oidc"
EOF
cp /opt/stack/horizon/openstack_dashboard/local/local_settings.py /opt/stack/horizon/openstack_dashboard/local/enabled/

# Restart Apache
sudo service apache2 restart
