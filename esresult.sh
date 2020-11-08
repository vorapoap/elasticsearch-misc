#!/usr/bin/env bash

KEYWORD_PLACEHOLDER="{{KEYWORD}}"
POST_QUERY='{ "query": {"match_all":{} }}'
RESULT_AMOUNT=6
CONTENT_TYPE_HEADER="Content-type: application/json"
TMP_FILE="/tmp/keyword.txt"
CSV_MODE=1
VERBOSE_MODE=0
NGRAM_MODE=0
JQ_SYNTAX=".hits.hits[]._source.locale.en | [.name, .brand_name]"

if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
	echo "The version (${BASH_VERSINFO}) of bash shell does not support associative arrays."
	echo "Please upgrade your /bin/bash. "
	exit
fi
if ! command -v jq &> /dev/null
then
    echo "jq command could not be found."
    echo "Please install jq command."
    exit
fi

help() ( 
	echo "${0} [url] [keyword]"
	echo "${0} [url] -q [query] -k keyword_file"
	echo "${0} [url] -d [post_data_file] [keyword]"
	echo "  -q [query]: Post query (default = {\"query:{\"match_all\":{}}"
	echo "  -d [post_data_file]: Post body query that contains placeholder (default = none and use match_all) "
	echo "  -p [keyword_placeholder]: Placeholder string to be replaced with performing keyword (default = ${KEYWORD_PLACEHOLDER})"
	echo "  -a [amount]: Amount of results to be displayed (default = ${RESULT_AMOUNT})"
	echo "  -H [header]: Content-type header (default = ${CONTENT_TYPE_HEADER})"
	echo "  -k [keyword_file]: Load keyword from file instead of search_keyword (default = None)"
	echo "  -f [jq_query_field]: Field(s) to be displayed in jq syntax (default = ${JQ_SYNTAX})"
	echo "  -v [mode=0,1,2] Turn on verbose mode (default = ${VERBOSE_MODE}"
	echo "  -r Disable CSV mode"
	echo "  -N Enable edge-n-gram mode from 3 characters"
)
verbose() {
	if (( ${VERBOSE_MODE} >= ${1} )); then 
		echo "debug${1}: ${2}"
	fi
	
}

while getopts "q:d:p:a:H:k:f:hrv:N"  option; do
	case $option in
		q)
			POST_QUERY=$OPTARG
			;;
		d)
			POST_DATA_FILE=$OTPARG
			;;
		p)
			KEYWORD_PLACEHOLDER=$OPTARG
			;;
		a)
			RESULT_AMOUNT=$OPTARG
			;;
		H)
			CONTENT_TYPE_HEADER=$OPTARG
			;;
		k)
			KEYWORD_FILE=$OPTARG
			;;
		f)
			JQ_SYNTAX=$OPTARG
			;;
		r) 
			CSV_MODE=0
			;;
		v)
			VERBOSE_MODE=$OPTARG
			;;
		N)  
			NGRAM_MODE=1
			;;	
		\?)
            echoerr "Invalid option -$OPTARG"
			help
			exit 1
			;;	
	esac
done

shift "$((OPTIND-1))"

POST_URL="$1"
SEARCH_KEYWORD="$2"

# Not provide POST_URL
if [[ -z "$POST_URL" ]] ; then
	help
	exit 1
fi

# Provide POST_DATA_FILE and not exist POST_DATA_FILE
if [[ ! -z "$POST_DATA_FILE" ]] && [[ ! -f "$POST_DATA_FILE" ]]; then
	echo "Post data file ${POST_DATA_FILE} does not exist."
	exit 1
fi

# Not provide SEARCH_KEYWORD and not provide KEYWORD_FILE
if [[ -z "$SEARCH_KEYWORD" ]] && [[ -z "$KEYWORD_FILE" ]]; then
	echo "Either search_keyword or keyword_file needed to be specfied"
	help
	exit 1
fi

# Provide KEYWORD_FILE and not exist KEYWORD_FILE 
if [[ ! -z "$KEYWORD_FILE" ]] && [[ ! -f "$KEYWORD_FILE" ]]; then
	echo "Keyword file ${KEYWORD_FILE} does not exist."
	exit 1
fi

# Provide SEARCH_KEYWORD
if [[ ! -z "$SEARCH_KEYWORD" ]]; then
	KEYWORD_FILE="${TMP_FILE}"
	echo ${SEARCH_KEYWORD} > ${TMP_FILE}
fi

# Provide POST_DATA_FILE
if [[ ! -z "$POST_DATA_FILE" ]]; then
	POST_QUERY=`cat ${POST_DATA_FILE}`
	verbose "Found ${#POST_QUERY} byte(s) in ${POST_DATA_FILE} for POST body."
fi

verbose 1 "Post URL = ${POST_URL}"
KEYWORD_LINE=0

declare -A PERFORMED_KEYWORD
verbose 1 "Working with keyword file: ${KEYWORD_FILE} ${SEARCH_KEYWORD}"


while IFS= read -r KEYWORD ; do
	KEYWORD=$(echo ${KEYWORD} | xargs)
	KEYWORD_LEN=${#KEYWORD}
	KEYWORD_LINE=$((KEYWORD_LINE+1))
	INITIAL_LEN=$((KEYWORD_LEN))
	if [[ "${KEYWORD_LEN}" < 3 ]] || [[ ! -n "$PERFORMED_KEYWORD[${KEYWORD}]" ]]; then
		continue
	fi
	PERFORMED_KEYWORD[$KEYWORD]=1

	if (( $NGRAM_MODE > 0 )); then
		INITIAL_LEN=3
	fi

	for (( I=INITIAL_LEN; I<=KEYWORD_LEN; I++ )) ; do		
		KEYWORD_NGRAM="${KEYWORD:0:${I}}" 
		verbose 1 "Line: ${KEYWORD_LINE} - Len: ${KEYWORD_LEN} - Ngram Keyword: ${KEYWORD_NGRAM}"

		QUERY=${POST_QUERY//${KEYWORD_PLACEHOLDER}/${KEYWORD_NGRAM}} # No need to replace newline and escape double quote
		verbose 2 "{$QUERY}"
		RESULT=`curl -sS -XPOST --insecure "${POST_URL}" -H "${CONTENT_TYPE_HEADER}" -d "${QUERY}" --stderr - `
		#echo $QUERY
		#echo ${RESULT} | jq "${JQ_SYNTAX}" --compact-output
		if (( $CSV_MODE > 0 )); then
			echo ${RESULT} | jq -r "${JQ_SYNTAX} | @csv" --compact-output | sed "s/.*/${KEYWORD_NGRAM},&/" 
		else
			echo ${RESULT} | jq -r "${JQ_SYNTAX}" --compact-output
		fi 
	done
done < "$KEYWORD_FILE"

if [[ "$TMP_FILE" = "$KEYWORD_FILE" ]];
then
	unlink $TMP_FILE
fi


