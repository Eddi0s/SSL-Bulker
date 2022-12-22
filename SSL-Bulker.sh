#!/bin/bash

BREED=$(wc -L host.list | awk '{print $1 + 5}')
CertNameBreed=$(wc -L host.list | awk '{print $1 + 5}')

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
printf "%-${BREED}s %-20s %-40s %-30s %-${CertNameBreed}s %-20s %-20s\n" "Domain" "IP" "Server" "DNS" "Cert Name" "CA's" "Exp Date"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

while read Domain; do
IP=$(host $Domain | awk 'NR==1{print $4}')
SERVER=$(host $IP | awk 'NR==1{print $5}')
SERVER=${SERVER%.*}



ExpDate=$(timeout 1s bash -c "echo 'Q' | openssl s_client -servername $Domain -connect $Domain:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -c 10-")

if [ "$ExpDate" = "" ]; then
  ExpDate="TimeOut"
fi

CertName=$(timeout 1s bash -c "echo 'Q' | openssl s_client -connect $Domain:443 2>&1 | openssl x509 -noout -text" | sed -n 11p | sed 's/^.*=//' | sed -r 's/^.{1}//' )

if [ "$CertName" = "" ]; then
  CertName="TimeOut"
fi


CA=$(timeout 1s bash -c "echo "Q" | openssl s_client -servername $Domain -connect $Domain:443 2>/dev/null" | grep -m 1 'O =' | cut -d, -f4 | cut -c 6- | awk '{print $1;}')

if [ "$CA" = "" ]; then
  CA="TimeOut"
fi

DNS=$(dig ns $Domain | grep -A 3  ';; ANSWER SECTION:' | head -2 | tail -1 | awk '{ print $5}')

printf "%-${BREED}s %-20s %-40s %-30s %-${CertNameBreed}s %-20s %-20s\n" "$Domain" "$IP" "$SERVER" "$DNS" "$CertName" "$CA" "$ExpDate"

done <host.list

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
