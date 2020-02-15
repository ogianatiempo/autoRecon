#!/bin/bash

####################################
# Inspired in nahamsec's lazyrecon #
# To use install nahamsec's bbht   #
####################################

####################################
#            Configuration         #
####################################
auquatoneThreads=2
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
    cat $reconFolder/$domain/$subFolder/sublist3r_temp.txt | sort -u > $reconFolder/$domain/$subFolder/sublist3r.txt
    rm $reconFolder/$domain/$subFolder/sublist3r_temp.txt
}

mass(){
    ~/tools/massdns/scripts/subbrute.py $massdnsWordlist $domain | sort -u | ~/tools/massdns/bin/massdns -r ~/tools/massdns/lists/resolvers.txt -t A -q -o S | awk  '{print $1}' | while read line; do
        x="$line"
        echo "${x%?}" >> $reconFolder/$domain/$subFolder/mass.txt
    done
}

searchcrtsh(){
    ~/tools/massdns/scripts/ct.py $domain 2>/dev/null | sort -u | ~/tools/massdns/bin/massdns -r ~/tools/massdns/lists/resolvers.txt -t A -q -o S | awk  '{print $1}' | while read line; do
        x="$line"
        echo "${x%?}" >> $reconFolder/$domain/$subFolder/crtsh.txt
    done
}

mergeDomains(){
    cat $reconFolder/$domain/$subFolder/sublist3r.txt >> $reconFolder/$domain/$subFolder/allDomains_tmp.txt
    cat $reconFolder/$domain/$subFolder/mass.txt >> $reconFolder/$domain/$subFolder/allDomains_tmp.txt
    cat $reconFolder/$domain/$subFolder/crtsh.txt >> $reconFolder/$domain/$subFolder/allDomains_tmp.txt

    sort -u $reconFolder/$domain/$subFolder/allDomains_tmp.txt > $reconFolder/$domain/$subFolder/allDomains.txt

    rm $reconFolder/$domain/$subFolder/allDomains_tmp.txt
}

httpprobe(){
    cat $reconFolder/$domain/$subFolder/allDomains.txt | httprobe -c 50 -t 10000 > $reconFolder/$domain/$subFolder/responsiveDomains.txt
    echo  "${yellow}Total of $(wc -l $reconFolder/$domain/$subFolder/responsiveDomains.txt | awk '{print $1}') live subdomains were found${reset}"
}

aquatone(){
    cat $reconFolder/$domain/$subFolder/responsiveDomains.txt | aquatone -chrome-path $chromiumPath -out $reconFolder/$domain/$subFolder/aqua_out -threads $auquatoneThreads -silent -http-timeout 10000
}

waybackrecon(){
    mkdir $reconFolder/$domain/$subFolder/wayback-data

    cat $reconFolder/$domain/$subFolder/responsiveDomains.txt | waybackurls > $reconFolder/$domain/$subFolder/wayback-data/waybackurls.txt

    cat $reconFolder/$domain/$subFolder/wayback-data/waybackurls.txt  | sort -u | unfurl --unique keys > $reconFolder/$domain/$subFolder/wayback-data/paramlist.txt
    [ -s $reconFolder/$domain/$subFolder/wayback-data/paramlist.txt ] && echo "Wordlist saved to /$domain/$foldername/wayback-data/paramlist.txt"

    cat $reconFolder/$domain/$subFolder/wayback-data/waybackurls.txt  | sort -u | grep -P "\w+\.js(\?|$)" | sort -u > $reconFolder/$domain/$subFolder/wayback-data/jsurls.txt
    [ -s $reconFolder/$domain/$subFolder/wayback-data/jsurls.txt ] && echo "JS Urls saved to /$domain/$foldername/wayback-data/jsurls.txt"

    cat $reconFolder/$domain/$subFolder/wayback-data/waybackurls.txt  | sort -u | grep -P "\w+\.php(\?|$) | sort -u " > $reconFolder/$domain/$subFolder/wayback-data/phpurls.txt
    [ -s $reconFolder/$domain/$subFolder/wayback-data/phpurls.txt ] && echo "PHP Urls saved to /$domain/$foldername/wayback-data/phpurls.txt"

    cat $reconFolder/$domain/$subFolder/wayback-data/waybackurls.txt  | sort -u | grep -P "\w+\.aspx(\?|$) | sort -u " > $reconFolder/$domain/$subFolder/wayback-data/aspxurls.txt
    [ -s $reconFolder/$domain/$subFolder/wayback-data/aspxurls.txt ] && echo "ASP Urls saved to /$domain/$foldername/wayback-data/aspxurls.txt"

    cat $reconFolder/$domain/$subFolder/wayback-data/waybackurls.txt  | sort -u | grep -P "\w+\.jsp(\?|$) | sort -u " > $reconFolder/$domain/$subFolder/wayback-data/jspurls.txt
    [ -s $reconFolder/$domain/$subFolder/wayback-data/jspurls.txt ] && echo "JSP Urls saved to /$domain/$foldername/wayback-data/jspurls.txt"
}

dirsearch(){
    mkdir $reconFolder/$domain/$subFolder/dirsearch

    cat $reconFolder/$domain/$subFolder/responsiveDomains.txt | while read line; do
        of=$(echo $line | sed 's/\http\:\/\//http_/g' |  sed 's/\https\:\/\//https_/g')
        echo "Running dirsearch for ${line}"
        python3 ~/tools/dirsearch/dirsearch.py -e php,asp,aspx,jsp,html,zip,jar -w $dirsearchWordlist -t $dirsearchThreads -u ${line} --plain-text-report $reconFolder/$domain/$subFolder/dirsearch/${of}
    done
}

## Directory creation
echo "Target domain:"
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

mergeDomains

echo "Probing for live hosts"
httpprobe

# Discovery
echo "Starting aquatone scan"
aquatone

echo "Scraping wayback for data"
waybackrecon

echo "Searching for directories"
dirsearch