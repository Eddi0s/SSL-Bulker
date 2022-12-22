#!/bin/bash

BREED=$(wc -L host.list | awk '{print $1 + 5}')
CertNameBreed=$(wc -L host.list | awk '{print $1 + 5}')

echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
printf "%-${BREED}s %-20s %-40s %-30s %-${CertNameBreed}s %-20s %-20s\n" "Domain" "IP" "Server" "DNS" "Cert Name" "CA's" "Exp Date"
echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

while read Domain; do
IP=$(host $Domain | awk 'NR==1{print $4}')
SERVER=$(host $IP | awk 'NR==1{print $5}')
SERVER=${SERVER%.*}







# Voer het dig commando uit en sla het resultaat op in een variabele
DNS=$(dig ns $Domain)

# Controleer of de AUTHORITY SECTION of QUESTION SECTION voorkomt in het resultaat

if echo "$DNS" | grep -q ";; AUTHORITY SECTION:"; then
  DNS=$(echo "$DNS" | sed -n '/;; AUTHORITY SECTION:/,+1p' | tail -n 1 | awk '{print $5;}')

elif echo "$DNS" | grep -q ";; ANSWER SECTION"; then
  DNS=$(echo "$DNS" | sed -n '/;; ANSWER SECTION/,+1p' | tail -n 1 | awk '{print $5;}')
fi


















ExpDate=$(timeout 2s bash -c "echo 'Q' | openssl s_client -servername $Domain -connect $Domain:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -c 10-")

if [ "$ExpDate" = "" ]; then
  ExpDate="TimeOut"
fi

CertName=$(timeout 2s bash -c "echo 'Q' | openssl s_client -connect $Domain:443 2>&1 | openssl x509 -noout -text" | sed -n 11p | sed 's/^.*=//' | sed -r 's/^.{1}//' )

if [ "$CertName" = "" ]; then
  CertName="TimeOut"
fi

CA=$(timeout 2s bash -c "echo "Q" | openssl s_client -servername $Domain -connect $Domain:443 2>/dev/null" | grep -m 1 'O =' | cut -d, -f4 | cut -c 6- | awk '{print $1;}')

if [ "$CA" = "" ]; then
  CA="TimeOut"
fi

printf "%-${BREED}s %-20s %-40s %-30s %-${CertNameBreed}s %-20s %-20s\n" "$Domain" "$IP" "$SERVER" "$DNS" "$CertName" "$CA" "$ExpDate"

done <host.list

echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
