#!/bin/bash

BREED=$(wc -L host.list | awk '{print $1 + 5}')
CertNameBreed=$(wc -L host.list | awk '{print $1 + 5}')

# Noteer het starttijdstip
start_time=$(date +%s)

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

# Defineer rood-kleur
RED=$(tput setaf 1)

# Defineer groen-kleur
GREEN=$(tput setaf 2)
# Defineer standaard kleur
RESET=$(tput sgr0)

# Sla ExpDate output op in ExpDate variabele
ExpDate=$(timeout 2s bash -c "echo 'Q' | openssl s_client -servername $Domain -connect $Domain:443 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -c 10-")

# Parseer de output van de ExpDate variabele en sla de datum op in de EXP_DATE_PARSED variabele
EXP_DATE_PARSED=$(date -d "$ExpDate" +%s)

# Haal de huidige datum op en sla deze op in de CURRENT_DATE variabele
CURRENT_DATE=$(date +%s)

# Bereken het aantal seconden tot twee maanden verval
TWO_MONTHS_IN_SECONDS=$((60*60*24*60))

if [ "$ExpDate" = "" ]; then
 ExpDate="${RED}TimeOut${RESET}"
fi

# Als de vervaldatum binnen twee maanden valt, kleur de output rood
if [ $((EXP_DATE_PARSED - CURRENT_DATE)) -lt $TWO_MONTHS_IN_SECONDS ]; then
  ExpDate="${RED}$ExpDate${RESET}"
else
  # Als de vervaldatum langer dan twee maanden in de toekomst ligt, kleur de output groen
  ExpDate="${GREEN}$ExpDate${RESET}"
fi

CertName=$(timeout 2s bash -c "echo 'Q' | openssl s_client -connect $Domain:443 2>&1 | openssl x509 -noout -text" | sed -n 11p | sed 's/^.*=//' | sed -r 's/^.{1}//' )

if [ "$CertName" = "" ]; then
  CertName="${RED}TimeOut${RESET}"
fi

CA=$(timeout 2s bash -c "echo "Q" | openssl s_client -servername $Domain -connect $Domain:443 2>/dev/null" | grep -m 1 'O =' | cut -d, -f4 | cut -c 6- | awk '{print $1;}')

if [ "$CA" = "" ]; then
  CA="${RED}CA not found${RESET}"
fi

printf "%-${BREED}s %-20s %-40s %-30s %-${CertNameBreed}s %-20s %-20s\n" "$Domain" "$IP" "$SERVER" "$DNS" "$CertName" "$CA" "$ExpDate"

done <host.list

echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

echo "Scanned on $(date)"

# Noteer het eindtijdstip
end_time=$(date +%s)

# Bereken het verschil tussen het eind- en starttijdstip
elapsed_time=$((end_time - start_time))

# Weergeef het verschil in seconden
echo "Script took $elapsed_time seconds to finish"

