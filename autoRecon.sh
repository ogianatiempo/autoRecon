#!/bin/bash

####################################
# Inspired in nahamsec's lazyrecon #
# To use install nahamsec's bbht   #
####################################

####################################
#            Configuration         #
####################################
auquatoneThreads=5
subdomainThreads=10
dirsearchThreads=50
dirsearchWordlist=~/tools/dirsearch/db/dicc.txt
massdnsWordlist=~/tools/SecLists/Discovery/DNS/clean-jhaddix-dns.txt
chromiumPath=/snap/bin/chromium
reconFolder=~/recon
subFolder=recon-$(date +"%Y-%m-%d")
####################################

red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`

usage() { echo -e "Usage: ./autoRecon.sh -d domain.com [-e] [excluded.domain.com,other.domain.com]\nOptions:\n  -e\t-\tspecify excluded subdomains\n " 1>&2; exit 1; }

while getopts ":d:e:" o; do
    case "${o}" in
        d)
            domain=${OPTARG}
            ;;

            #### working on subdomain exclusion
        e)
            set -f
	    IFS=","
	    excluded+=($OPTARG)
	    unset IFS
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "${domain}" ]; then
   usage; exit 1;
fi

sublist3r(){
    python ~/tools/Sublist3r/sublist3r.py -d $domain -t 10 -v -o $reconFolder/$domain/$subFolder/sublist3r_temp.txt > /dev/null
    sed -i 's/<BR>/\n/g' $reconFolder/$domain/$subFolder/sublist3r_temp.txt # Fixes <BR> bug
    cat $reconFolder/$domain/$subFolder/sublist3r_temp.txt | sort | uniq > $reconFolder/$domain/$subFolder/sublist3r.txt
    rm $reconFolder/$domain/$subFolder/sublist3r_temp.txt
}

mass(){
    ~/tools/massdns/scripts/subbrute.py $massdnsWordlist $domain | sort | uniq | ~/tools/massdns/bin/massdns -r ~/tools/massdns/lists/resolvers.txt -t A -q -o S | awk  '{print $1}' | while read line; do
        x="$line"
        echo "${x%?}" >> $reconFolder/$domain/$subFolder/mass.txt
    done
}

searchcrtsh(){
    ~/tools/massdns/scripts/ct.py $domain 2>/dev/null | sort | uniq | ~/tools/massdns/bin/massdns -r ~/tools/massdns/lists/resolvers.txt -t A -q -o S | awk  '{print $1}' | while read line; do
        x="$line"
        echo "${x%?}" >> $reconFolder/$domain/$subFolder/crtsh.txt
    done
}


## Directory creation
echo "Starting enumeration on:"
echo "${green}${domain}${reset}"
if [[ -n ${excluded} ]]; then
    echo "Excluded subdomains:"
    echo "${yellow}${excluded[*]}${reset}"
fi

if [[ ! -e $reconFolder ]]; then
    echo "Creating recon folder"
    mkdir $reconFolder
fi

if [[ ! -e $reconFolder/$domain ]]; then
    echo "${domain} is a new target."
    echo "Creating target directory"
    mkdir $reconFolder/$domain
else
    echo "${domain} is a known target"
fi

if [[ -e $reconFolder/$domain/$subFolder ]]; then
    echo "Target already scanned today"
    exit
fi

mkdir $reconFolder/$domain/$subFolder

# Subdomain enumeration
echo "Starting subdomain enumeration"
echo "Running sublis3r"
sublist3r
echo "Running massdns subbrute"
mass
echo "Running massdns cert.sh"
searchcrtsh