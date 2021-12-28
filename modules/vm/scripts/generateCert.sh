#!/usr/bin/bash

# Inputs for service certificates
OCONT=IN # Country
OSTATE=Karnataka # State
OLOCATION=Bangalore # City
OORG=Appnomic # Organization
OORGUNIT=Engg # Organization unit
OCOMMONNAME='*xyz.com' # Common name [ hostname or ipaddress ]
OENCRYPTIONBIT=1024 # Number of bits to use for generating certificate key file
OEXPIREDAYS=1650 # Number of days to expire

# Subject alternative name. Hostname or ip address to be allowed for the certificate
#SAN1='abc.saas.xyz.com'
CACERTDIR="/tmp"
function convertdnspem() {
    var=" "
    count=1
    count1=1
    for line in `grep '^SAN' conf.sh | cut -d = -f2 | sed -e "s/'//g"`
    do
        if [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]];then
            var="$var\n IP.$count = $line"
            ((count++))
        else
            var="$var\n DNS.$count1 = $line"
            ((count1++))
        fi
    done
    echo -e $var | sed -e '/^$/d;s/^ //'
}

function pem() {
    # Create server Key
    echo "Generating pem RSA key"
    openssl genrsa -out xyz.key $OENCRYPTIONBIT
    #echo "Extracting pkc12 format private key for mle"
    # For SAN
    #logit "Adding configured SAN from config file"
    #MYSAN=`convertdnspem`
    echo "[ v3_req ]
    basicConstraints = CA:FALSE
    keyUsage = nonRepudiation, digitalSignature, keyEncipherment, keyCertSign, keyAgreement
    subjectAltName = @alt_names

    [ alt_names ]
    DNS.1 = customername.xyz.com" > ext.conf
    echo "Generating server signing request which will signed using CA"
    # Create server csr
    openssl req -new -sha256 -extensions v3_req -key xyz.key -subj "/C=$OCONT/ST=$OSTATE/L=$OLOCATION/O=$OORG/OU=$OORGUNIT/CN=$OCOMMONNAME" -out xyz.csr
    echo "Generatng server certificate after signing using CA"
    # Create server cert
    openssl x509 -req -extensions v3_req -days $OEXPIREDAYS -in xyz.csr -CA $CACERTDIR/xyz-rootca.crt -CAkey $CACERTDIR/xyz-rootca.key -CAcreateserial -out xyz.crt -sha256 -extfile ext.conf
    return 0
}

pem

yes | cp -f xyz.key /etc/nginx/
yes | cp -f xyz.crt /etc/nginx/