#!/bin/bash
#please note this workflow is a scripted version (w/ a few extra features) of a manual workflow medium article I DID NOT WRITE
#early on i found it helpful as a practice exercise to automate manual workflows of existing tools
autotest=1
runonfile=0
loudmode=0
runonsubdomain=0
usage() {
	echo "Usage: $0 [options] <domain-name-or-filepath>"
	echo "Options:"
	echo " -a Disable autotest"
	echo " -h Display this help message"
	echo " -f Run on txt file containing domain names"
	echo " -s Turn off silencing"
	echo " -d Run on just one subdomain"
	exit 1
}

#parse options
while getopts "ahfsd" opt; do
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
		s)
			loudmode=1
			;;
		d)
			runonsubdomain=1
			;;
		\?)
			echo "invalid option: -$OPTARG" >&2
			usage
			;;
	esac
done

#remove options processed by getopts
shift $((OPTIND - 1))

#check for domain name or filepath positional argument
if [[ "$#" -ne 1 ]]; then
	echo "${runonfile}"
	if [ ${runonfile} -eq 0 ]; then
		echo "Enter exactly one domain name"
		usage
	else
		echo "Enter exactly one filepath positional argument"
	fi
fi

#cleanup from previous runs
rm -r paramspider/paramspider/results/*

#define colors, because pretty
BRIGHT_MAGENTA='\u001b[35;1m'
NO_COLOR='\033[0m'
domain_name_or_filepath=$1

scanner() {
	domain_name=$1
	#enter running directory
	cd paramspider
	if [ "${runonsubdomain}" -eq 1 ]; then
		echo ${domain_name} > ${domain_name}sub.txt
	else
		#run subfinder
		subfinder -d ${domain_name} -o ${domain_name}sub.txt
	fi

	#find 200 responses
	cat ${domain_name}sub.txt | httpx -mc 200 > 200_${domain_name}_urls.txt

	#enter running directory
	cd paramspider

	#Run paramspider
	python3 main.py -l ../200_${domain_name}_urls.txt

	cd results
	#collect into one file
	cat *.txt >> ${domain_name}result.txt

	#find xss vectors
	cat ${domain_name}result.txt | kxss > kxss_vectors.txt

	echo -e "Completed kxss findings for: ${BRIGHT_MAGENTA}${domain_name}${NO_COLOR}"

	#check if autotest is on
	if [ "${autotest}" -eq 1 ]; then
		echo 'autotest is on, ^C to terminate'
		cat kxss_vectors.txt | tr -d '\n' > temporary.txt
		sed "s/URL: /\n/g" temporary.txt > processed_kxss.txt
		rm temporary.txt
		#filter to the most promising targets
		grep '< >\|{ }' processed_kxss.txt > promising_kxss.txt
		target_count=$(wc -l < promising_kxss.txt)
		cat promising_kxss.txt
		echo -e "Running on ${BRIGHT_MAGENTA}${target_count}${NO_COLOR} possible targets"
		sed 's/ Param:.*//' promising_kxss.txt > formatted_promising_kxss.txt
		cat formatted_promising_kxss.txt
        #change the ***** sections to be your hackerone username if you want to identify yourself as non-malicious to programs
		if [ "${loudmode}" -eq 1 ]; then
			dalfox -H "X-h1-researcher:*****" --user-agent "HackerOneResearch *****" file formatted_promising_kxss.txt
		else
			dalfox -H "X-h1-researcher:*****" --user-agent "HackerOneResearch *****" --silence file formatted_promising_kxss.txt
		fi
		echo -e "Scan and PoC complete for ${BRIGHT_MAGENTA}${domain_name}${NO_COLOR}"
	else
		cat kxss_vectors.txt
		echo 'autotest has been turned off'
	fi
	cd ..
	cd ..
	cd ..
}

if [ ${runonfile} -eq 1 ]; then
	echo -e "RUNNING IN ${BRIGHT_MAGENTA}FILEMODE${NO_COLOR}"
	while read line; do scanner $line; done < ${domain_name_or_filepath}
else
	echo -e "RUNNING IN ${BRIGHT_MAGENTA}DOMAIN MODE${NO_COLOR}"
	scanner ${domain_name_or_filepath}
fi