
#  elasticsearch-misc
### Custom scripts for Elasticsearch
## Requirements
 * Bash version 4.x+
 * Curl
 * Jq - https://stedolan.github.io/jq/

## Script "esresult.sh"
**Benchmark search query in Elasticsearch with option to create report in CSV format**

    ./esresult.sh [url] [keyword]
    ./esresult.sh [url] -q [query] -k keyword_file
    ./esresult.sh [url] -d [post_data_file] [keyword]
      -q [query]: Post query (default = {"query:{"match_all":{}}
      -d [post_data_file]: Post body query that contains placeholder (default = none and use match_all)
      -p [keyword_placeholder]: Placeholder string to be replaced with performing keyword (default = {{KEYWORD}})
      -H [header]: Content-type header (default = Content-type: application/json)
      -k [keyword_file]: Load keyword from file instead of search_keyword (default = None)
      -f [jq_query_field]: Field(s) to be displayed in jq syntax (default = .hits.hits[] | [._score, ._source.locale.en.name, ._source.locale.en.brand_name, ._source.locale.th.name, ._source.locale.th.brand_name])
      -v [mode=0,1,2] Turn on verbose mode (default = 0
      -r Disable CSV mode
      -N Enable edge-n-gram mode from 3 characters

### Examples

###  
    ./esresult.sh -r -f "[] | [.name]" -q "{\"query\":{\"match\": {\"name\":\"{{KEYWORD}}\"}}}" \
      https://localhost:9200/names/_search John\

1. Replace {{KEYWORD}} in the query with John 
2. Disable CSV mode (-r)
3. Request the Elasticsearch end-point at   https://localhost:9200/names/_search John\
4. Output the result parsed directly by jq of .name

### Transform each keyword through edge-n-gram step and perform a query
    ./esresult.sh -N -d search.json \
      -k 440-en-keyword.txt \
      https://localhost:9200/product/_search \
      > 440-en-keyword.result.txt &

1. Load search.json to be used in a POST query
2. For each keyword in file 440-en-keyword.txt, replace every occurrence of "{{KEYWORD}}" in the POST query with each keyword in file 440-en-keyword.txt line by line 
3. Enable edge-N-gram mode (starting from 3 characters to the maximum of each keyword's length 
4. Request the Elasticsearch end-point at https://localhost:9200/product/_search and use jq to output the parsed result of as pre-defined in **jq_query_field**  
5. Re-direct the output to the file 440-en-keyword.result.txt

**Output is in following CSV format**

    LINENO,TIME_SPENT,NGRAM,SCORE,EN_NAME,EN_BRAND_NAME,TH_NAME,TH_BRAND_NAME

Created by Vorapoap Lohwongwatana
The script is provided without any warranty.
