#!/bin/bash

HOST=localhost
USERNAME=chalindu
DATABASE=postgres
PORT=5432
CSV_FILE="query_results.csv"

execute_insert_query() {
    local query="INSERT INTO kind (value) VALUES ('{\"kind\": \"Component\", \"spec\": {\"type\": \"miJob\", \"build\": {\"default\": {\"port\": \"6331111\", \"version\": \"1.x\"}}, \"source\": {\"github\": {\"path\": \"hello-world\", \"branch\": \"main\", \"repository\": \"https://github.com/example/choreo-samples/tree/main/hello-world\"}}}, \"level1\": {\"level2\": {\"level3\": {\"level4\": {\"level5\": {\"level6\": {\"level7\": {\"level8\": {\"level9\": {\"value9\": \"push\", \"level10\": {\"value10\": \"chance\"}}, \"value8\": \"condition\"}, \"value7\": \"big\"}, \"value6\": \"he\"}, \"value5\": \"involve\"}, \"value4\": \"investment\"}, \"value3\": \"kid\"}, \"value2\": \"situation\"}, \"value1\": \"customer\"}, \"metadata\": {\"name\": \"sarah_hammond\", \"displayName\": \"Sarah Hammond\", \"projectName\": \"monitor\"}, \"apiVersion\": \"core.choreo.dev/v1alpha1\"}'::jsonb);"
    local result=$(psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -c "\timing" -c "explain analyze $query")
    local execution_time=$(echo "$result" | grep "Execution Time:" | awk '{print $3}')
    local total_times=$(echo "$result" | grep -oE 'Time: [0-9.]+ ms' | awk '{print $2}')
    local total_time=$(echo "$total_times" | awk 'NR==3{print $1}')
    echo "$execution_time, $total_time"
}

execute_query() {
    local query="$1"
    local result=$(psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -c "\timing" -c "explain analyze $query")
    local execution_time=$(echo "$result" | grep "Execution Time:" | awk '{print $3}')
    local total_times=$(echo "$result" | grep -oE 'Time: [0-9.]+ ms' | awk '{print $2}')
    # Execute the SQL query
    local total_time=$(echo "$total_times" | awk 'NR==3{print $1}')
    echo "$execution_time, $total_time"
}

main() {
    local iterations="$1"
    local query_name="$2"
    local query="$3"
    local query_type=$(echo "$3" | awk '{print tolower($1)}')  # Extract query type from the first argument and convert to lowercase], print the first field (word) from each input line
    local sum_execution_time=0
    local sum_total_time=0

    for i in $(seq "$iterations"); do
        echo "Executing query iteration $i..."
        if [ $query_type = 'insert' ]; then
            result=$(execute_insert_query)
        else
            result=$(execute_query "$query")
        fi
        execution_time=$(echo "$result" | cut -d',' -f1)
        total_time=$(echo "$result" | cut -d',' -f2)
        echo "Execution time: $execution_time, Total time: $total_time"
        sum_execution_time=$(echo "$sum_execution_time + $execution_time" | bc)
        sum_total_time=$(echo "$sum_total_time + $total_time" | bc)
    done

    # Calculate the average execution and total time
    average_execution_time=$(echo "scale=2; $sum_execution_time / $iterations" | bc)
    average_total_time=$(echo "scale=2; $sum_total_time / $iterations" | bc)

    # Get row count from the database, -t helps to avoid printing addition details
    echo "Get row count from the database..."
    row_count=$(psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -t -c "SELECT COUNT(value) FROM kind;")
    row_count_millions=$(echo "scale=3; $row_count / 1000000" | bc)  # Round off to millions

    # Check if there are any indexes on the table
    echo "Get index info from the database..."
    indexes_count=$(psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -t -c "SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'kind';")
    has_indexes="No"
    if [ "$indexes_count" -gt 0 ]; then
        has_indexes="Yes"
    fi

    local index_info=""
    local index_name=""
    local index_definition=""
    if [ "$has_indexes" == "No" ]; then
        index_name="Without Indexing"
    else
        index_info=$(psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -c "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'kind';")
        # Split index_info into separate variables for index name and definition
        index_name=$(echo "$index_info" | awk 'NR==3{print $1}')
        index_definition=$(echo "$index_info" | awk 'NR==3 { for (i=3; i<=NF; i++) printf "%s ", $i; printf "\n" }')
    fi

    # DB Size
    echo "Get table size from the database..."
    local table_size
    table_size=$(PGPASSWORD=PLJ3C7ncRF4USZ+QElxQkQ psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE} -c "SELECT pg_size_pretty( pg_total_relation_size('kind') );")
    local size
    size=$(echo "$table_size" | awk 'NR==3 { for (i=1; i<=NF; i++) printf "%s ", $i; printf "\n" }')

    local queried_row_count=0
    if [ $query_type = 'select' ]; then 
        result=$(psql -h "${HOST}" -p "${PORT}" -U "${USERNAME}" -d "${DATABASE}" -c "$query")
        queried_row_count=$(echo "$result" | awk 'BEGIN {count=0} NR > 2 {count++} END {print count}')
        queried_row_count=$((queried_row_count - 1))  # Subtract 1
    fi
    # Write results to CSV file
    current_timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    if [ -f "$CSV_FILE" ]; then
        echo "$query_type, $query_name,$row_count,$row_count_millions,  \"$index_name\", $average_total_time,$average_execution_time,\"$query\",\"$has_indexes\", \"$index_definition\", $iterations, $current_timestamp, $queried_row_count, $size"  >> "$CSV_FILE"
    else
        echo "Query Type, Query Name,Row Count,Row Count (Millions), Index Name, Average Total Time (ms),Average Execution Time (ms),Query,Has Indexes, Index Definition,Sample Count, Current Timestamp, Queried Row Count, Table Size" > "$CSV_FILE"
        echo "$query_type, $query_name,$row_count,$row_count_millions,  \"$index_name\", $average_total_time,$average_execution_time,\"$query\",\"$has_indexes\", \"$index_definition\", $iterations, $current_timestamp, $queried_row_count, $size" >> "$CSV_FILE"
    fi
    echo "Results written to $CSV_FILE"
}

# Usage
if [ "$#" -ne 3 ]; then
    if ! ([ $(echo "$3" | awk '{print tolower($1)}') == "insert" ]); then
        echo "Usage: $0 <sample count> <query name> <query>"
        exit 1
    fi
fi

main "$1" "$2" "$3"

postgres=# SELECT tablename, pg_size_pretty(pg_total_relation_size(tablename)) AS total, pg_size_pretty(pg_relation_size(tablename)) AS table, pg_size_pretty(pg_indexes_size(tablename)) AS index FROM (SELECT ('"' || table_schema || '"."' || table_name || '"') AS tablename FROM information_schema.tables WHERE table_name = 'kind') AS subquery;
