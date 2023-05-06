#!/bin/bash

# This script reads a list of domain names from the file "host.list" and performs various checks and queries for each domain.
# The output of each query is formatted into a table for easy readability.

# Calculate the required padding for the "Width" and "CertNameWidth" columns in the output table.
Width=$(wc -L host.list | awk '{print $1 + 5}')
CertNameWidth=$(wc -L host.list | awk '{print $1 + 5}')

# Get the current timestamp for calculating the script's runtime.
start_time=$(date +%s)

# Print the header row for the output table.
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"printf "%-${Width}s %-20s %-40s %-30s %-${CertNameWidth}s %-20s %-20s\n" "Domain" "IP" "Server" "DNS" "Cert Name" "CA's" "Exp Date"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
# Loop through each line (domain) in the host.list file.
while read -r Domain; do

 # Query the domain's IP address and server name.
 IP=$(host $Domain | grep -m1 -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
 if [ -z "$IP" ]; then
  IP="NOT FOUND"
  SERVER="NOT FOUND"
 else
 SERVER=$(host $IP | awk 'NR==1{print $5}' | cut -c1-35 | sed 's/\.$//')
 fi

  # Query the domain's DNS name.
  DNS=$(dig ns $Domain | grep -m1 -E "IN\s*(NS|SOA)\s" | awk '{ print $5 }' | cut -c1-30 | sed 's/\.$//' )

  # If the domain's DNS name is "ns1.dns.nl.", consider it as not found.
  if [ "$DNS" = "ns1.dns.nl." ]; then
    DNS="NOT FOUND"
  fi

  # Query the domain's SSL certificate name and extract it from the response.
  CertName=$(echo | openssl s_client -servername $Domain -showcerts -connect $Domain:443 2>/dev/null)
  if echo "$CertName" | grep -q "BEGIN CERTIFICATE"; then
    CertName=$(echo "$CertName" | openssl x509 -noout -subject | awk '{print $NF}')
  else
    CertName="NOT FOUND"
  fi

  # Query the domain's SSL certificate's CA name and extract it from the response.
  CA=$(echo | openssl s_client -servername "$Domain" -showcerts -connect "$Domain":443 2>/dev/null)
  if echo "$CA" | grep -q "BEGIN CERTIFICATE"; then
    CA=$(echo "$CA" | openssl x509 -noout -issuer | awk -F= '/CN =/{print $NF}' | awk '{print $1}')
  else
    CA="NOT FOUND"
  fi

  # Query the domain's SSL expiration date and extract it from the response.
  ExpDate=$(timeout 2s bash -c "echo 'Q' | openssl s_client -servername $Domain -connect $Domain:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null")

  # If the output of openssl s_client contains the string "notAfter", extract the expiration date and assign it to the ExpDate variable
  if echo "$ExpDate" | grep -q "notAfter"; then
   ExpDate=$(echo "$ExpDate" | grep notAfter | cut -c 10-)
  else
  # If the output does not contain "notAfter", set the expiration date to "NOT FOUND"
   ExpDate="NOT FOUND"
  fi

# Print the domain, IP address, server name, DNS name, certificate name, CA, and expiration date
printf "%-${Width}s %-20s %-40s %-30s %-${CertNameWidth}s %-20s %-20s\n" "$Domain" "$IP" "$SERVER" "$DNS" "$CertName" "$CA" "$ExpDate"

# Loop through each domain in the "host.list" file
done <host.list

# Print a separator line
echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

# Print the current date and time
echo "Scanned on $(date)"

# Calculate the total time the script took to run and print it
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

# Print elapsed time for runtime script
echo "Script took $elapsed_time seconds to finish"
