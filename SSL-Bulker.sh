#!/bin/bash

# This script reads a list of domain names from the file "host.list" and performs various checks and queries for each domain.
# The output of each query is formatted into a table for easy readability.

# Controleer en verwijder lege regels uit host.list
sed -i '/^ *$/d' host.list

# Calculate the required padding for the "Width" and "CertNameWidth" columns in the output table.
Width=$(wc -L host.list | awk '{print $1 + 5}')
CertNameWidth=$(wc -L host.list | awk '{print $1 + 5}')
Num_Domains=$(wc -l host.list | awk '{print $1}')

# Define RED color
RED=$(tput setaf 1)
# Define GREEN color
GREEN=$(tput setaf 2)
# Define ORANGE color
ORANGE=$(tput setaf 202)
# Define standard color
RESET=$(tput sgr0)

# Get the current timestamp for calculating the script's runtime.
start_time=$(date +%s)

# Print the header row for the output table.
echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
printf "%-${Width}s %-20s %-40s %-30s %-${CertNameWidth}s %-20s %-20s\n" "Domain" "IP" "Server" "DNS" "Cert Name" "CA's" "Exp Date"
echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

# Loop through each line (domain) in the host.list file.
while read -r Domain; do

# Query the domain's IP address and server name with a timeout of 2 seconds.
IP=$(timeout 2s host $Domain | grep -m1 -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

if [ -z "$IP" ]; then
  IP="NOT FOUND"
  SERVER="NOT FOUND"
else
  SERVER=$(timeout 2s host $IP | awk 'NR==1{print $5}' | cut -c1-35 | sed 's/\.$//')
fi

# Query the domain's DNS name with a timeout of 2 seconds.
DNS=$(timeout 2s dig ns $Domain | grep -m1 -E "IN\\s*(NS|SOA)\\s" | awk '{ print $5 }' | cut -c1-30 | sed 's/\\.$//')

# Check if the value of the DNS variable is empty or equal to "ns1.dns.nl."
if [ -z "$DNS" ] || [ "$DNS" = "ns1.dns.nl." ]; then
  DNS="NOT FOUND"
fi


# Query the domain's SSL certificate name and extract it from the response with a timeout of 2 seconds.
CertName=$(timeout 2s bash -c "{ echo | openssl s_client -servername $Domain -showcerts -connect $Domain:443 2>/dev/null; }" || echo "TIMED OUT")
if echo "$CertName" | grep -q "BEGIN CERTIFICATE"; then
  CertName=$(echo "$CertName" | openssl x509 -noout -subject | awk '{print $NF}')
fi

# Query the domain's SSL certificate's CA name and extract it from the response with a timeout of 2 seconds.
CA=$(timeout 2s bash -c "{ echo | openssl s_client -servername \"$Domain\" -showcerts -connect \"$Domain\":443 2>/dev/null; }" || echo "TIMED OUT")
if echo "$CA" | grep -q "BEGIN CERTIFICATE"; then
  CA=$(echo "$CA" | openssl x509 -noout -issuer | awk -F= '/CN =/{print $NF}' | awk '{print $1}')
fi


  # Query the domain's SSL expiration date and extract it from the response.
  ExpDate=$(timeout 2s bash -c "echo 'Q' | openssl s_client -servername $Domain -connect $Domain:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null")

  # If the output of openssl s_client contains the string "notAfter", extract the expiration date and assign it to the ExpDate variable
  if echo "$ExpDate" | grep -q "notAfter"; then
   ExpDate=$(echo "$ExpDate" | grep notAfter | cut -c 10-)
  else
  # If the output does not contain "notAfter", set the expiration date to "NOT FOUND"
   ExpDate="TIMED OUT"
  fi

# Get the current date and store it in the CURRENT_DATE variable
CURRENT_DATE=$(date +%s)

# Calculate the number of seconds to two months of expiration
TWO_MONTHS_IN_SECONDS=$((60*60*24*60))

# This block of code checks the expiration date of the certificate
if echo "$ExpDate" | grep -q "TIMED OUT"; then
  ExpDate="TIMED OUT"
else
  EXP_DATE_PARSED=$(date -d "$ExpDate" +%s)
  SECONDS_UNTIL_EXPIRATION=$((EXP_DATE_PARSED - CURRENT_DATE))

  if [ $SECONDS_UNTIL_EXPIRATION -lt 0 ]; then
    ExpDate="${RED}$ExpDate${RESET}"  # Certificate has already expired, make it red
  elif [ $SECONDS_UNTIL_EXPIRATION -lt $TWO_MONTHS_IN_SECONDS ]; then
    ExpDate="${ORANGE}$ExpDate${RESET}"  # Certificate will expire within two months, make it orange
  else
    ExpDate="${GREEN}$ExpDate${RESET}"  # Certificate is valid for more than two months, make it green
  fi
fi

# This code block contains an if-else statement to check whether the IP variable is "NOT FOUND".
# If it is, it will print the variable in red color using the printf command, else it will print in the normal format.

if [ "$IP" = "TIMED OUT" ] || [ "$CA" = "TIMED OUT" ] || [ "$ExpDate" = "TIMED OUT" ]; then
        printf "\033[31m%-${Width}s\033[0m \033[31m%-20s\033[0m \033[31m%-40s\033[0m \033[31m%-30s\033[0m \033[31m%-${CertNameWidth}s\033[0m \033[31m%-20s\033[0m \033[31m%-20s\033[0m\n" "$Domain" "$IP" "$SERVER" "$DNS" "$CertName" "$CA" "$ExpDate"
else
        printf "%-${Width}s %-20s %-40s %-30s %-${CertNameWidth}s %-20s %-20s\n" "$Domain" "$IP" "$SERVER" "$DNS" "$CertName" "$CA" "$ExpDate"
fi

# Loop through each domain in the "host.list" file
done <host.list

# Print a separator line
echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

# Print the current date and time
echo "Scanned on $(date)"

# Calculate the total time the script took to run and print it
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

# Print elapsed time for runtime script
echo "Scanned $Num_Domains domains in $elapsed_time seconds"
