#! /usr/bin/env bash

# Sets up MIT Kerberos for Cloudera Manager in the Cloudera QuickStart VM

UNLIMITED_JCE_POLICY_ZIP=/home/cloudera/Downloads/UnlimitedJCEPolicyJDK7.zip

if [ ! -e ${UNLIMITED_JCE_POLICY_ZIP} ]; then
    echo "Please download the Unlimited JCE Policy zip file from Oracle to ${UNLIMITED_JCE_POLICY_ZIP}!"
    exit 1
fi

REALM=${REALM:-CLOUDERA}
DOMAIN=${DOMAIN:-cloudera}
HOSTNAME=${HOSTNAME:-quickstart.${DOMAIN}}
JAVA_HOME=${JAVA_HOME:-/usr/java/jdk1.7.0_55-cloudera}

# install Unlimited Strength JCE files
unzip ${UNLIMITED_JCE_POLICY_ZIP}
mv UnlimitedJCEPolicy/*.jar ${JAVA_HOME}/jre/lib/security/

yum install -y krb5-server krb5-workstation openldap

cat > /etc/krb5.conf <<EOF
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 default_realm = ${REALM}
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true

[realms]
 ${REALM} = {
  kdc = ${HOSTNAME}
  admin_server = ${HOSTNAME}
  max_renewable_life = 7d 0h 0m 0s
  default_principal_flags = +renewable
 }

[domain_realm]
 .${DOMAIN} = ${REALM}
 ${DOMAIN} = ${REALM}
EOF

cat > /var/kerberos/krb5kdc/kdc.conf <<EOF
[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88

[realms]
 ${REALM} = {
  #master_key_type = aes256-cts
  acl_file = /var/kerberos/krb5kdc/kadm5.acl
  dict_file = /usr/share/dict/words
  admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
  supported_enctypes = aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal
  max_life = 30d
  max_renewable_life = 30d
 }
EOF

echo "*/admin@${REALM}  *" > /var/kerberos/krb5kdc/kadm5.acl

