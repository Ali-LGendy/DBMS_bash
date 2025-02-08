#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
clear='\033[0m'

activeDB=""

validate_and_collect_values() {
    local -a column_array=()
    local -a type_array=()
    
    local i=0
    for arg in "$@"; do
        if ((i < ($# / 2))); then
            column_array+=("$arg")
        else
            type_array+=("$arg")
        fi
        ((i++))
    done
    
    local values=()
    for i in "${!column_array[@]}"; do
        local column="${column_array[$i]}"
        local type="${type_array[$i]}"
        
        while true; do
            read -p "Enter value for column '$column' ($type): " value
            
            if [[ "$type" == "int" && ! "$value" =~ ^-?[0-9]+$ ]]; then
                echo -e "${red}Invalid input: '$value' is not an integer.${clear}"
                continue
            elif [[ "$type" == "string" && -z "$value" ]]; then
                echo -e "${red}Invalid input: String value cannot be empty.${clear}"
                continue
            fi
            
            values+=("$value")
            break
        done
    done
    
    local IFS=','
    echo "${values[*]}"
}

validate_input() {
    local value="$1"
    local type="$2"
    local column="$3"
    
    if [[ "$type" == "int" && ! "$value" =~ ^-?[0-9]+$ ]]; then
        echo -e "${red}Invalid input: '$value' is not an integer for column '$column'.${clear}"
        return 1
    elif [[ "$type" == "string" && -z "$value" ]]; then
        echo -e "${red}Invalid input: String value cannot be empty for column '$column'.${clear}"
        return 1
    fi
    return 0
}

check_table_exists() {
    local metadata_file="$1"
    local table_name="$2"
    
    if ! grep -q "^$table_name," "$metadata_file"; then
        echo -e "${red}Table '$table_name' does not exist.${clear}"
        return 1
    fi
    return 0
}

create_table() {
    local metadata_file="$1/metadata.csv"
    local flag=0
    
    echo -e "${blue}Create table for database $(basename "$1")${clear}\n"
    
    if [ ! -f "$metadata_file" ]; then
        echo "table_name,column_name,data_type,is_primary_key" > "$metadata_file"
    fi
    
    while true; do
        read -p "Enter table name: " table_name
        if [ -z "$table_name" ]; then
            echo -e "${red}No table name entered. Exiting.${clear}"
            return
        fi
        
        if [[ ! "$table_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            echo -e "${red}Invalid table name: Table name must start with a letter and can only contain letters, numbers, or underscores.${clear}"
            continue
        fi
        
        if grep -q "^$table_name," "$metadata_file"; then
            echo -e "${yellow}Table already exists!${clear}"
        else
            echo -e "${green}Table created successfully!${clear}"
            local primary_flag=0
            
            while true; do
                read -p "Enter number of columns: " columns_num
                
                if ! [[ $columns_num =~ ^-?[0-9]+$ ]]; then
                    echo -e "${red}Error: Input is not a number.${clear}"
                elif [ $columns_num -le 0 ]; then
                    echo -e "${red}Error: Value must be greater than zero.${clear}"
                else
                    break
                fi
            done
            
            local index=0
            while [ $index -lt $columns_num ]; do
                while true; do
                    read -p "Enter column name for column $((index + 1)): " column_name
                    
                    if [ -z "$column_name" ]; then
                        echo -e "${red}Error: Column name cannot be empty.${clear}"
                    elif [[ ! "$column_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                        echo -e "${red}Invalid input: First character must be a letter.${clear}"
                    else
                        break
                    fi
                done
                
                while true; do
                    read -p "Enter column type for column $((index + 1)) (int/string): " column_type
                    
                    if [ -z "$column_type" ]; then
                        echo -e "${red}Error: Column type cannot be empty.${clear}"
                    elif [[ "$column_type" != "int" && "$column_type" != "string" ]]; then
                        echo -e "${red}Invalid column type! Only 'int' or 'string' allowed.${clear}"
                    else
                        break
                    fi
                done
                
                local is_primary_key=0
                if [ $index -eq 0 ] && [ $primary_flag -eq 0 ]; then
                    primary_flag=1
                    is_primary_key=1
                fi
                
                echo "$table_name,$column_name,$column_type,$is_primary_key" >> "$metadata_file"
                ((index++))
            done
            
            touch "$1/$table_name.csv"
        fi
        
        while true; do
            read -p "Do you want to create another table? (y/n): " choice
            if [[ "$choice" =~ ^[Yy]$ ]]; then
                break
            elif [[ "$choice" =~ ^[Nn]$ ]]; then
                break 2
            else
                echo -e "${red}Invalid input: Enter y/n only.${clear}"
            fi
        done
    done
}

load_columns_and_types() {
    local metadata_file="$1/metadata.csv"
    local table_name="$2"

    if [ ! -f "$metadata_file" ]; then
        echo -e "${red}Metadata file not found. Please create tables first.${clear}"
        return 1
    fi

    if ! grep -q "^$table_name," "$metadata_file"; then
        echo -e "${red}Table '$table_name' does not exist.${clear}"
        return 1
    fi

    columns=$(grep "^$table_name," "$metadata_file" | cut -d',' -f2 | tr '\n' ' ')
    types=$(grep "^$table_name," "$metadata_file" | cut -d',' -f3 | tr '\n' ' ')
    primary_key=$(grep "^$table_name," "$metadata_file" | awk -F',' '$4 == 1 {print $2}' | head -n 1)

    echo "$columns"
    echo "$types"
    echo "$primary_key"
}

insert_into_table() {
    local metadata_file="$1/metadata.csv"
    local data_dir="$1"

    read -p "Enter table name: " table_name

    metadata=$(load_columns_and_types "$1" "$table_name")
    if [ $? -ne 0 ]; then
        return
    fi

    read -r -a column_array <<< "$(echo "$metadata" | head -n 1)"
    read -r -a type_array <<< "$(echo "$metadata" | head -n 2 | tail -n 1)"
    primary_key_column=$(echo "$metadata" | tail -n 1)

    data_file="$data_dir/$table_name.csv"
    touch "$data_file"

    row=$(validate_and_collect_values "${column_array[@]}" "${type_array[@]}")
    
    primary_key_value=$(echo "$row" | cut -d',' -f1)
    
    if grep -q "^$primary_key_value," "$data_file"; then
        echo -e "${red}Error: Primary key '$primary_key_value' already exists.${clear}"
        return 1
    fi

    echo "$row" >> "$data_file"
    
    echo -e "${blue}Row inserted successfully!${clear}"
    echo -e "${green}Current data:${clear}"
    cat "$data_file"
}

list_table() {
    local metadata="$1/metadata.csv"
    if [ ! -f "$metadata" ]; then
        echo -e "${red}No tables found.${clear}"
        return
    fi
    
    while IFS=',' read -r table_name col_name data_type is_primary_key; do
        if [[ "$is_primary_key" == "1" ]]; then
            echo -e "${green}$table_name.$col_name ($data_type) (Primary Key)${clear}"
        else
            echo -e "${green}$table_name.$col_name ($data_type)${clear}"
        fi
    done < "$metadata"
}

drop_table() {
    list_table "$1"
    read -p "Enter table name to drop: " table_name
    
    if [ -f "$1/$table_name.csv" ]; then
        rm -f "$1/$table_name.csv"
        sed -i "/^$table_name,/d" "$1/metadata.csv"
        echo -e "\n${blue}Table '$table_name' dropped successfully!${clear}"
    else
        echo -e "\n${red}Table '$table_name' does not exist!${clear}"
    fi
}

update_table() {
    local metadata_file="$1/metadata.csv"
    local data_dir="$1"

    read -p "Enter table name: " table_name

    metadata=$(load_columns_and_types "$1" "$table_name")
    if [ $? -ne 0 ]; then
        return
    fi

    read -r -a column_array <<< "$(echo "$metadata" | head -n 1)"
    read -r -a type_array <<< "$(echo "$metadata" | head -n 2 | tail -n 1)"
    primary_key_column=$(echo "$metadata" | tail -n 1)

    data_file="$data_dir/$table_name.csv"
    
    echo -e "${green}Current data in table:${clear}"
    cat "$data_file"
    
    read -p "Enter the value of the primary key ('$primary_key_column') to update: " primary_key_value

    if ! grep -q "^$primary_key_value," "$data_file"; then
        echo -e "${red}No row found with primary key value '$primary_key_value'.${clear}"
        return
    fi

    row=$(validate_and_collect_values "${column_array[@]}" "${type_array[@]}")

    sed -i "/^$primary_key_value,/c$row" "$data_file"
    
    echo -e "${blue}Row updated successfully!${clear}"
    echo -e "${green}Updated data:${clear}"
    cat "$data_file"
}

get_row_data() {
    read -p "Enter table name: " table_name
    read -p "Enter primary key: " value

    search_table="$1/$table_name.csv"

    if [ ! -f "$search_table" ]; then
        echo -e "${red}Table not found.${clear}"
        return 1
    fi

    local result=$(grep "^$value," "$search_table")

    if [ -n "$result" ]; then
        echo "$result|$table_name"
    fi
}

select_from_table() {
    local result=$(get_row_data "$1")

    if [ -z "$result" ]; then
        echo -e "${red}No rows found.${clear}"
    else
        local row_data=$(echo "$result" | cut -d'|' -f1)
        echo -e "${blue}--------------------- The result is ---------------------${clear}"
        echo -e "${green}$row_data${clear}"
        echo -e "${blue}---------------------------------------------------------${clear}"
    fi
}

delete_from_table() {
    local result=$(get_row_data "$1")

    if [ -z "$result" ]; then
        echo -e "${red}No rows found.${clear}"
        return 1
    fi

    local row_data=$(echo "$result" | cut -d'|' -f1)
    local table_name=$(echo "$result" | cut -d'|' -f2)
    
    local primary_key_value=$(echo "$row_data" | cut -d',' -f1)

    if [ -n "$primary_key_value" ] && [ -n "$table_name" ]; then
        sed -i "/^$primary_key_value,/d" "$1/$table_name.csv"
        
        if grep -q "^$primary_key_value," "$1/$table_name.csv"; then
            echo -e "${red}Error: Row deletion failed.${clear}"
        else
            echo -e "${blue}Row deleted successfully.${clear}"
        fi
    else
        echo -e "${red}Error: Invalid data received.${clear}"
    fi
}

show_sub_menu() {
    local menu="
${yellow}+---------- ${green} sub Menu ${yellow}----------+
|    ${blue}1) Create Table${clear}            |
|    ${green}2) List Tables${clear}             |
|    ${red}3) Drop Table${clear}              |
|    ${blue}4) Insert into Table${clear}       |
|    ${green}5) Select From Table${clear}       |
|    ${red}6) Delete From Table${clear}       |
|    ${blue}7) Update Table${clear}            |
|    ${green}8) Exit${clear}                    |
+-------------------------------+${clear}
"

    activeDB="$1"
    
    while true; do
        echo -e "$menu"
        read -p "Select an option: " option
        echo
        
        case $option in 
            1) create_table "$activeDB" ;;
            2) list_table "$activeDB" ;;
            3) drop_table "$activeDB" ;;
            4) insert_into_table "$activeDB" ;;
            5) select_from_table "$activeDB" ;;
            6) delete_from_table "$activeDB" ;;
            7) update_table "$activeDB" ;;
            8) echo -e "${blue}Bye\n${clear}"; break ;;
            *) echo -e "${red}Invalid option, try again!\n${clear}" ;;
        esac
    done
}