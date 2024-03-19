#!/bin/bash

HOST=localhost
USERNAME=chalindu
DATABASE=postgres
PORT=5432
CSV_FILE="query_results.csv"

if ! [ -f "$CSV_FILE" ]; then
    echo "Query Type, Query Name,Row Count,Row Count (Millions), Iteration, Index Name, Total Time, Unit, Execution Time, Unit, Planning Time, Has Indexes,Sample Count, Current Timestamp, Queried Row Count, Total Size, Table Size, Index Size, Index Definition, Query" > "$CSV_FILE"
fi

execute_insert_query() {
    local query="INSERT INTO kind (value) VALUES ('{\"kind\": \"Component\", \"spec\": {\"type\": \"miJob\", \"build\": {\"default\": {\"port\": \"6331111\", \"version\": \"1.x\"}}, \"source\": {\"github\": {\"path\": \"hello-world\", \"branch\": \"main\", \"repository\": \"https://github.com/example/choreo-samples/tree/main/hello-world\"}}}, \"level1\": {\"level2\": {\"level3\": {\"level4\": {\"level5\": {\"level6\": {\"level7\": {\"level8\": {\"level9\": {\"value9\": \"push\", \"level10\": {\"value10\": \"chance\"}}, \"value8\": \"condition\"}, \"value7\": \"big\"}, \"value6\": \"he\"}, \"value5\": \"involve\"}, \"value4\": \"investment\"}, \"value3\": \"kid\"}, \"value2\": \"situation\"}, \"value1\": \"customer\"}, \"metadata\": {\"name\": \"sarah_hammond\", \"displayName\": \"Sarah Hammond\", \"projectName\": \"monitor\"}, \"apiVersion\": \"core.choreo.dev/v1alpha1\"}'::jsonb);"
    local result
    result=$(PGPASSWORD=${DB_PASSOWRD} psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -c "\timing" -c "explain analyze $query")
    local execution_time
    execution_time=$(echo "$result" | grep "Execution Time:" | awk '{ for (i=3; i<=4; i++) printf "%s ", $i; printf "\n" }')
    local planning_time
    planning_time=$(echo "$result" | grep "Planning Time:" | awk '{ for (i=3; i<=4; i++) printf "%s ", $i; printf "\n" }')
    local total_times
    total_time=$(echo "$result" | grep -oE 'Time: [0-9.]+ ms' | awk 'NR==3{ for (i=2; i<=3; i++) printf "%s ", $i; printf "\n" }')
    echo "$execution_time, $total_time", "$planning_time"
}

execute_query() {
    local query="$1"
    local result
    result=$(PGPASSWORD=${DB_PASSOWRD} psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -c "\timing" -c "explain analyze $query")
    local execution_time
    execution_time=$(echo "$result" | grep "Execution Time:" | awk '{ for (i=3; i<=4; i++) printf "%s ", $i; printf "\n" }')
    local planning_time
    planning_time=$(echo "$result" | grep "Planning Time:" | awk '{ for (i=3; i<=4; i++) printf "%s ", $i; printf "\n" }')
    local total_times
    total_time=$(echo "$result" | grep -oE 'Time: [0-9.]+ ms' | awk 'NR==3{ for (i=2; i<=3; i++) printf "%s ", $i; printf "\n" }')
    echo "$execution_time, $total_time", "$planning_time"
}

main() {
    local iterations="$1"
    local query_name="$2"
    local query="$3"
    local query_type
    query_type=$(echo "$3" | awk '{print tolower($1)}')  # Extract query type from the first argument and convert to lowercase], print the first field (word) from each input line
    
    # Get row count from the database, -t helps to avoid printing addition details
    echo "Get row count from the database..."
    local row_count
    row_count=$(PGPASSWORD=${DB_PASSOWRD} psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -t -c "SELECT COUNT(value) FROM kind;")
    local row_count_millions
    row_count_millions=$(echo "scale=3; $row_count / 1000000" | bc)  # Round off to millions

    # Check if there are any indexes on the table
    echo "Get index info from the database..."
    local indexes_count
    indexes_count=$(PGPASSWORD=${DB_PASSOWRD} psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -t -c "SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'kind';")
    local has_indexes
    has_indexes="No"
    if [ "$indexes_count" -gt 0 ]; then
        has_indexes="Yes"
    fi

    local index_info=""
    local index_name=""
    local index_definition=""
    if [ "$has_indexes" = "No" ]; then
        index_name="Without Indexing"
    else
        index_info=$(PGPASSWORD=${DB_PASSOWRD} psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -c "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'kind';")
        # Split index_info into separate variables for index name and definition
        index_name=$(echo "$index_info" | awk 'NR==3{print $1}')
        index_definition=$(echo "$index_info" | awk 'NR==3 { for (i=3; i<=NF; i++) printf "%s ", $i; printf "\n" }')
    fi
    
    # DB Size
    echo "Get table size from the database..."
    local table_size
    size_result=$(PGPASSWORD=${DB_PASSOWRD} psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -c "SELECT tablename, pg_size_pretty(pg_total_relation_size(tablename)) AS total, pg_size_pretty(pg_relation_size(tablename)) AS table, pg_size_pretty(pg_indexes_size(tablename)) AS index FROM (SELECT table_schema || '.' || table_name AS tablename FROM information_schema.tables WHERE table_name = 'kind') AS subquery;")
    local total_size
    local table_size
    local index_size
    total_size=$(echo "$size_result" | awk 'NR==3 { for (i=3; i<=4; i++) printf "%s ", $i; printf "\n" }')
    table_size=$(echo "$size_result" | awk 'NR==3 { for (i=6; i<=7; i++) printf "%s ", $i; printf "\n" }')
    index_size=$(echo "$size_result" | awk 'NR==3 { for (i=9; i<=10; i++) printf "%s ", $i; printf "\n" }')

    local queried_row_count=0
    if [ $query_type = 'select' ]; then 
        result=$(PGPASSWORD=${DB_PASSOWRD} psql -h "${HOST}" -p "${PORT}" -U "${USERNAME}" -d "${DATABASE}" -c "$query")
        queried_row_count=$(echo "$result" | awk 'BEGIN {count=0} NR > 2 {count++} END {print count}')
	queried_row_count=$((queried_row_count - 1))  # Subtract 1
    fi
    # Write results to CSV file
    local current_timestamp


    echo "Started the script"
    for i in $(seq "$iterations"); do
        echo "Executing query iteration $i..."
        if [ $query_type = 'insert' ]; then
            result=$(execute_insert_query)
        else
            result=$(execute_query "$query")
        fi
        local execution_time
	    execution_time=$(echo "$result" | cut -d',' -f1)
        local total_time
	    total_time=$(echo "$result" | cut -d',' -f2)
        local planning_time
        planning_time=$(echo "$result" | cut -d',' -f3)

        current_timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        echo "$query_type, $query_name,$row_count,$row_count_millions,$i,$index_name, $(echo "$total_time" | awk '{print $1}'), $(echo "$total_time" | awk '{print $2}'),$(echo "$execution_time" | awk '{print $1}'), $(echo "$execution_time" | awk '{print $2}'), $(echo "$planning_time" | awk '{print $1}'),$has_indexes, $iterations, $current_timestamp, $queried_row_count,$total_size,$table_size,$index_size,$index_definition,$query" >> "$CSV_FILE"
    done
    
    echo "Results written to $CSV_FILE"
}

# Usage
if [ "$#" -ne 3 ]; then
    if ! ([ $(echo "$3" | awk '{print tolower($1)}') = "insert" ]); then
        echo "Usage: $0 <sample count> <query name> <query>"
        exit 1
    fi
fi

main "$1" "$2" "$3"
