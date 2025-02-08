#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;93m'
blue='\033[0;94m'

clear='\033[0m'

if [ -f "./sub_menu.sh" ]; then
    source ./sub_menu.sh
else
    echo -e "${red}Error: sub_menu.sh not found!${clear}"
    exit 1
fi

rootFile="./DBMS"

if [ ! -d "$rootFile" ]; then
    mkdir -p "$rootFile"
fi

create_database()
{
    read -p "Enter database name: " database_name

    if [[ $database_name =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    
        if [ -d "$rootFile/$database_name" ]; then
            echo "#################################"
            echo -e "##${red}  Database already exists!   ${clear}##"
            echo "#################################"
        else
            mkdir -p "$rootFile/$database_name"
            echo -e "${blue}Database '$database_name' created successfully!${clear}"
        fi

    else
        echo -e "${red}Invalid input: First character can't be special character, or number${clear}"
    fi
}

list_databases()
{
    echo -e "\n+------------------------+"
    echo -e "${yellow}Databases:${clear}"
    echo -e "+------------------------+"

    databases=$(ls -F "$rootFile" | grep "/" | cut -d'/' -f1)

    if [ -z "$databases" ]; then
        echo -e "${red}No databases found.${clear}\n"
    else
        echo -e "\n${green}$databases${clear}\n"
        echo -e "+------------------------+"
    fi
}

connect_database()
{
    list_databases

    read -p "Enter database name to connect: " database_name

    if [ -z "$database_name" ]; then
        echo -e "${red}No database name entered. Exiting.${clear}"
        return
    fi

    if [ -d "$rootFile/$database_name" ]; then

        echo -e "\n${blue}Connected to '$database_name'.${clear}"
        show_sub_menu "$rootFile/$database_name" 
        echo -e "\n${blue}Disconnected from '$database_name'.${clear}"

    else
        echo -e "\n${red}Database '$database_name' does not exist!${clear}"
    fi
}

drop_database()
{
    list_databases

    read -p "Enter database name to drop: " database_name

    if [ -z "$database_name" ]; then
        echo -e "${red}No database name entered. Exiting.${clear}"
        return
    fi

    if [ -d "$rootFile/$database_name" ]; then

        while true; do
            read -p "Are you sure you want to delete the database '$database_name'? (y/n) " confirm

            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -rf "$rootFile/$database_name"
                echo -e "${blue}Database '$database_name' deleted successfully.${clear}"
                break
            elif [[ "$confirm" =~ ^[Nn]$ ]]; then
                echo -e "${yellow}Deletion canceled.${clear}"
                break
            else
                echo -e "${red}Invalid input: Input character must be y or n only. try again!${clear}"
            fi

        done

    else
        echo -e "\n${red}Database '$database_name' does not exist!${clear}"
    fi
}

show_main_menu()
{
    local menu="
${yellow}+---------- ${green}Main Menu ${yellow}----------+
|    1. Create Database         |
|    2. List Databases          |
|    3. Connect to Database     |
|    4. Drop Database           |
|    5. Exit                    |
+-------------------------------+
${clear}"

    while true; do
        echo -e "\n$menu"
        read -p "Select an option: " option
        echo

        case $option in
            1)
                clear
                create_database
                ;;
            2)
                clear
                list_databases
                ;;
            3)
                clear
                connect_database
                ;;
            4)
                clear
                drop_database
                ;;
            5)
                clear
                echo -e "${blue}Bye!${clear}\n"
                break
                ;;
            *)
                clear
                echo -e "${red}Invalid option, try again!${clear}\n"
                ;;
        esac
    done
}

show_main_menu
