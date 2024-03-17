#!/bin/bash

HOST=localhost
USERNAME=chalindu
DATABASE=postgres
PORT=5432
CSV_FILE="query_results.csv"


execute_query() {
    local result=$(psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -c "\timing" -c "explain analyze INSERT INTO kind (value) VALUES ('{\"kind\": \"Component\", \"spec\": {\"type\": \"miJob\", \"build\": {\"default\": {\"port\": \"6331\", \"version\": \"1.x\"}}, \"source\": {\"github\": {\"path\": \"hello-world\", \"branch\": \"main\", \"repository\": \"https://github.com/example/choreo-samples/tree/main/hello-world\"}}}, \"level1\": {\"level2\": {\"level3\": {\"level4\": {\"level5\": {\"level6\": {\"level7\": {\"level8\": {\"level9\": {\"value9\": \"push\", \"level10\": {\"value10\": \"chance\"}}, \"value8\": \"condition\"}, \"value7\": \"big\"}, \"value6\": \"he\"}, \"value5\": \"involve\"}, \"value4\": \"investment\"}, \"value3\": \"kid\"}, \"value2\": \"situation\"}, \"value1\": \"customer\"}, \"metadata\": {\"name\": \"sarah_hammond\", \"displayName\": \"Sarah Hammond\", \"projectName\": \"monitor\"}, \"apiVersion\": \"core.choreo.dev/v1alpha1\"}'::jsonb);")
    local execution_time=$(echo "$result" | grep "Execution Time:" | awk '{print $3}')
    local total_times=$(echo "$result" | grep -oE 'Time: [0-9.]+ ms' | awk '{print $2}')
    local total_time=$(echo "$total_times" | awk 'NR==3{print $1}')
    echo "$execution_time, $total_time"
}

main() {
    execute_query
}

# Usage
# if [ "$#" -ne 3 ]; then
#     concatenated_string=$3
#     if [ $(echo "$3" | awk '{print tolower($1)}') == "insert" ]; then
#         # Concatenate strings stored in variables $3 and $4
#         concatenated_string="$3 $4"
#     else
#         echo "Usage: $0 <sample count> <query name> <query>"
#         exit 1
#     fi
#     echo "dd $1 $concatenated_string d "
    
# fi

main "$1" "$2" "$concatenated_string"
