#!/bin/bash

start=$(date "+%s.%N")

# -------------------------- INFO --------------------------

function basic () {
	proceed=false
	echo "Metagoofeel v1.1 ( github.com/ivan-sincek/metagoofeel )"
	echo ""
	echo "--- Crawl ---"
	echo "Usage:   ./metagoofeel.sh -d domain              [-r recursion]"
	echo "Example: ./metagoofeel.sh -d https://example.com [-r 20       ]"
	echo ""
	echo "--- Crawl and download ---"
	echo "Usage:   ./metagoofeel.sh -d domain              -k keyword [-r recursion]"
	echo "Example: ./metagoofeel.sh -d https://example.com -k all     [-r 20       ]"
	echo ""
	echo "--- Download from a file ---"
	echo "Usage:   ./metagoofeel.sh -f file                 -k keyword"
	echo "Example: ./metagoofeel.sh -f metagoofeel_urls.txt -k pdf"
}

function advanced () {
	basic
	echo ""
	echo "DESCRIPTION"
	echo "    Crawl through an entire website and download specific or all files"
	echo "DOMAIN (required)"
	echo "    Specify a domain you want to crawl"
	echo "    -d <domain> - https://example.com | https://192.168.1.10 | etc."
	echo "KEYWORD (required)"
	echo "    Specify a keyword to download only specific files"
	echo "    Use 'all' to download all files"
	echo "    -k <keyword> - pdf | js | png | all | etc."
	echo "RECURSION (optional)"
	echo "    Specify a maximum recursion depth"
	echo "    Use '0' for infinite"
	echo "    Default: 10"
	echo "    -r <recursion> - 0 | 5 | etc."
	echo "FILE (required)"
	echo "    Specify a file with [already crawled] URLs"
	echo "    -f <file> - metagoofeel_urls.txt | etc."
}

# -------------------- VALIDATION BEGIN --------------------

# my own validation algorithm

proceed=true

# $1 (required) - message
function echo_error () {
	echo "ERROR: ${1}"
}

# $1 (required) - message
# $2 (required) - help
function error () {
	proceed=false
	echo_error "${1}"
	if [[ $2 == true ]]; then
		echo "Use -h for basic and --help for advanced info"
	fi
}

declare -A args=([domain]="" [keyword]="" [recursion]="" [file]="")

# $1 (required) - key
# $2 (required) - value
function validate () {
	if   [[ $1 == "-d" && -z ${args[domain]} ]]; then
		args[domain]=$2
	elif [[ $1 == "-k" && -z ${args[keyword]} ]]; then
		args[keyword]=$2
	elif [[ $1 == "-r" && -z ${args[recursion]} ]]; then
		args[recursion]=$2
		if ! [[ ${args[recursion]} =~ ^[0-9]+$ ]]; then
			error "Recursion depth must be numeric"
		fi
	elif [[ $1 == "-f" && -z ${args[file]} ]]; then
		args[file]=$2
		if   ! [[ -e ${args[file]} ]]; then
			error "File does not exists"
		elif ! [[ -r ${args[file]} ]]; then
			error "File does not have read permission"
		elif ! [[ -s ${args[file]} ]]; then
			error "File is empty"
		fi
	fi
}

# $1 (required) - argc
# $2 (required) - args
function check() {
	local argc=$1
	local -n args_ref=$2
	local count=0
	for key in ${!args_ref[@]}; do
		if [[ ${args_ref[$key]} != "" ]]; then
			count=$((count + 1))
		fi
	done
	echo $((argc - count == argc / 2))
}

if [[ $# == 0 ]]; then
	advanced
elif [[ $# == 1 ]]; then
	if   [[ $1 == "-h" ]]; then
		basic
	elif [[ $1 == "--help" ]]; then
		advanced
	else
		error "Incorrect usage" true
	fi
elif [[ $(($# % 2)) -eq 0 && $# -le 6 ]]; then
	for key in $(seq 1 2 $#); do
		val=$((key + 1))
		validate ${!key} ${!val}
	done
	if [[ ${args[domain]} == "" && ${args[file]} == "" || ( ${args[domain]} != "" || ${args[recursion]} != "" ) && ${args[file]} != "" || $(check $# args) -eq false ]]; then
		error "Missing a mandatory option (-d) and/or optional (-k, -r)"
		error "Missing a mandatory option (-f, -k)" true
	fi
else
	error "Incorrect usage" true
fi

# --------------------- VALIDATION END ---------------------

# ----------------------- TASK BEGIN -----------------------

# $1 (required) - message
function timestamp () {
	local date=$(date "+%H:%M:%S %m-%d-%Y")
	echo "${1} -- ${date}"
}

function interrupt () {
	echo ""
	echo "[Interrupted]"
}

# $1 (required) - domain
# $2 (required) - recursion
# $3 (required) - output
function crawl () {
	echo "All crawled URLs will be saved in '${3}'"
	echo "You can tail the crawling progress with 'tail -f ${3}'"
	echo "Press CTRL + C to stop early"
	timestamp "Crawling has started"
	wget $1 -e robots=off -nv --spider --random-wait -nd --no-cache -r -l $2 -o $3
	timestamp "Crawling has ended  "
	grep -P -o "(?<=URL\:\ )[^\s]+(?=\ 200\ OK)" $3 | sort -u -o $3
	local count=$(grep -P "[^\s]+" $3 | wc -l)
	echo "Total URLs crawled: ${count}"
}

downloading=true

function interrupt_download () {
	downloading=false
	interrupt
}

# $1 (required) - keyword
# $2 (required) - output
function download () {
	local count=0
	local directory="metagoofeel_${1//\//\_}"
	echo "All downloaded files will be saved in '/${directory}/'"
	echo "Press CTRL + C to stop early"
	timestamp "Downloading has started"
	for url in $(cat $2); do
		if [[ $downloading == false ]]; then
			break
		fi
		if [[ $1 == "all" || $(echo $url | grep -i $1) ]]; then
			if [[ $(wget $url -e robots=off -nv -nc -nd --no-cache -P $directory 2>&1) ]]; then
				echo $url
				count=$((count + 1))
			fi
		fi
	done
	timestamp "Downloading has ended  "
	echo "Total files downloaded: ${count}"
}

if [[ $proceed == true ]]; then
	echo "########################################################################"
	echo "#                                                                      #"
	echo "#                           Metagoofeel v1.1                           #"
	echo "#                                  by Ivan Sincek                      #"
	echo "#                                                                      #"
	echo "# Crawl through an entire website and download specific or all files.  #"
	echo "# GitHub repository at github.com/ivan-sincek/metagoofeel.             #"
	echo "# Feel free to donate bitcoin at 1BrZM6T7G9RN8vbabnfXu4M6Lpgztq6Y14.   #"
	echo "#                                                                      #"
	echo "########################################################################"
	if [[ ${args[file]} != "" ]]; then
		trap interrupt_download INT
		download ${args[keyword]} ${args[file]}
		trap INT
	else
		output="metagoofeel_urls.txt"
		input="yes"
		if [[ -e $output ]]; then
			echo "Output file '${output}' already exists"
			read -p "Overwrite the output file (yes): " input
			echo ""
		fi
		if [[ $input == "yes" ]]; then
			trap interrupt INT
			crawl ${args[domain]} ${args[recursion]:-10} $output
			trap INT
			if [[ ${args[keyword]} != "" ]]; then
				echo ""
				read -p "Start downloading (yes): " input
				if [[ $input == "yes" ]]; then
					echo ""
					trap interrupt_download INT
					download ${args[keyword]} $output
					trap INT
				fi
			fi
		fi
	fi
	end=$(date "+%s.%N")
	runtime=$(echo "${end} - ${start}" | bc -l)
	echo ""
	echo "Script has finished in ${runtime}"
fi

# ------------------------ TASK END ------------------------
