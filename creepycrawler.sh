#!/bin/bash
#check the reachability of main site and absence of robots.txt

autotest=1
runonfile=0

usage() {
    echo "Usage: $0 [options] <domain-name-or-filepath>"
    echo "Options:"
    echo " -a Disable autotest"
    echo " -h Display this help message"
    echo " -f Run on txt file containing domain names"
    exit 1
}

# Parse options
while getopts "ahf" opt; do
    case $opt in
        a)
            autotest=0
            ;;
        h)
            usage
            ;;
        f)
            runonfile=1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
    esac
done
shift $((OPTIND - 1))

#check for domain name or filepath positional
if [[ "$#" -ne 1 ]]; then
    echo "Enter exactly one domain name or filepath"
    usage
fi

domain_name_or_filepath=$1

#colors <3
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_GREEN='\033[1;32m'
BRIGHT_RED='\033[1;31m'
NO_COLOR='\033[0m'

#check robots.txt and main site
check_robots_and_site() {
    local domain_name=$1
    local robots_url="https://${domain_name}/robots.txt"
    local main_site_url="https://${domain_name}"

    #check main site access
    local site_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 --head --request GET "${main_site_url}")

    if [[ "$site_status" -ge 200 ]] && [[ "$site_status" -lt 400 ]]; then
        #main site is accessible, check robots.txt
        local robots_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 --head --request GET "${robots_url}")

        if [[ "$robots_status" != "200" ]]; then
            echo -e "${BRIGHT_RED}Reachable Main Site but Unreachable robots.txt: ${domain_name}${NO_COLOR} - Robots Status: ${robots_status}"
            echo "${domain_name}" >> results.txt
        fi
    fi
}

process_domains() {
    local filepath=$1

    while read domain; do
        check_robots_and_site "$domain"
    done < "$filepath"
}

if [ ${runonfile} -eq 1 ]; then
    echo -e "RUNNING IN ${BRIGHT_YELLOW}FILE MODE${NO_COLOR}"
    process_domains "${domain_name_or_filepath}"
else
    echo -e "RUNNING IN ${BRIGHT_YELLOW}DOMAIN MODE${NO_COLOR}"
    check_robots_and_site "${domain_name_or_filepath}"
fi