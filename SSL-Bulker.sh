#!/bin/bash

BREED=$(wc -L host.list | awk '{print $1}')

echo "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
printf "%-${BREED}s %-20s %-30s %-30s %-20s %-20s %-20s\n" "Domain" "IP" "Server" "Cert Name" "CA's" "Exp Date"
echo "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

while read Domain; do
IP=$(host $Domain | awk 'NR==1{print $4}')
SERVER=$(host $IP | awk 'NR==1{print $5}')
SERVER=${SERVER%.*}
ExpDate=$(echo "Q" | openssl s_client -servername $Domain -connect $Domain:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -c 10-)
CertName=$(echo "Q" | openssl s_client -connect $Domain:443 2>&1 | openssl x509 -noout -text |  awk '/Subject: C=/{printf $NF"\n"} /DNS:/{x=gsub(/ *DNS:/, ""); printf "SANS=" $0"\n"}' | cut -c 6- | cut -f1 -d"," )
CA=$(echo "Q" | openssl s_client -servername $Domain -connect $Domain:443 2>/dev/null | grep -m 1 'O =' | cut -d, -f4 | cut -c 6- | awk '{print $1;}')

printf "%-${BREED}s %-20s %-30s %-30s %-20s %-20s %-20s\n" "$Domain" "$IP" "$SERVER" "$CertName" "$CA" "$ExpDate"

done <host.list

echo "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
