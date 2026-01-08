#!/bin/bash

# Configs

# ~~~~ dirs ~~~~
BIN_DIR="bin"
DUMP_ROOT_DIR="routines"
# ~~~~      ~~~~

# ~~~~ binary files ~~~~
XIDEL="./${BIN_DIR}/xidel"
HTMLQ="./${BIN_DIR}/htmlq"
URL_PARSER="./${BIN_DIR}/url-parser"
# ~~~~              ~~~~

# ~~~~ vars ~~~~
true="true"
false="false"
rt_class="class"
rt_term="term"
rt_supli="supli"
# ~~~~      ~~~~

# ~~~~ xpath exprs ~~~~
bisem_cls_expr="//div[@id='accordionClassRoutine']//table//tbody//tr"
trisem_cls_expr="//div[@id='Tri_Class_Routine']//table//tbody//tr"
exam_expr="//div[@id='Exam_Routine']//table//tbody//tr"
suppli_expr="//div[@id='Sup_Exam_Routine']//table//tbody//tr"
# ~~~~             ~~~~

RT_FILE="routine.html"

# end Configs


function xidel() {
    echo $($XIDEL -se "$1" "$2")
}


function htmlq() {
    echo $($HTMLQ "$1" -f "$2")
}

#######################################
# Prints log message
#
# Arguments:
#   first param  - log type.
#   second param - log message.
#######################################
function log() {
    log_type=$1
    log_msg=$2

    echo "[$log_type] - $log_msg"
}

#######################################
# Check if the string contains a string
# Arguments:
#   main string, first param.
#   substring, second param.
# Outputs:
#   $true - if string exists.
#   $false - if string not exists.
#######################################
function is_substr() { 
    if [[ $1 = *"$2"* ]]; then
        echo $true
    else
        echo $false
    fi
}

#######################################
# Compare two routine html file.
# Only the root table is compared to prevent spam.
#
# Arguments:
#   first param  - old file name.
#   second param - new file name.
#######################################
function compare_routine_html() {
    local old_file=$1
    local new_file=$2
    local root_table_css_selector="div#accordion"
    
    local old_table=$(htmlq "$root_table_css_selector" "$old_file")
    local new_table=$(htmlq "$root_table_css_selector" "$new_file")
    
    if [ "$old_table" = "$new_table" ];then
        echo $false
    else 
        echo $true
    fi
}


#######################################
# Pushes change to repo
#######################################
function push_update() {
    if [ -e "$RT_FILE" ]; then
        curl "https://classic.bubt.edu.bd/home/routines" -so "$RT_FILE.temp"
        if [ $(compare_routine_html "$RT_FILE" "$RT_FILE.temp") = $true ]; then
            log "INFO" "Links were updated. Deleting old $RT_FILE"
            rm -f "$RT_FILE"
            mv "$RT_FILE.temp" "$RT_FILE" && log "INFO" "renamed $RT_FILE.temp" || log "ERROR" "failed to rename $RT_FILE.temp"
        else
            log "INFO" "No links were updated. Deleting new $RT_FILE"
            rm -f "$RT_FILE.temp" && log "INFO" "deleted $RT_FILE.temp" || log "ERROR" "failed to delete $RT_FILE.temp"
        fi
    else
        curl "https://classic.bubt.edu.bd/home/routines" -so "$RT_FILE"
    fi    

    if [ $(git status --porcelain | wc -l) -eq "0" ]; then
        log "INFO" "no update."
    else
        log "INFO" "pushing new update"
        git config --local user.name 'github-actions[bot]'
        git config --local user.email '41898282+github-actions[bot]@users.noreply.github.com'
        git add .
        git commit -am "Updated on $(date -u '+%Y-%m-%d %H:%M:%S %Z')"
        git push    
    fi  
}


#######################################
# Download files or html page.
# when downloads a html page it uses the program id and semester id to sort the html files.
# default output directory format: $DUMP_ROOT_DIR/$rt_type/$sems/$file_path
# example: dump/class/bi/062/006.html
#
# Arguments:
#   first param  - url to download.
#   second param - whether semester is Bisemester ($true or $false).
#   third param  - routine type ($rt_class, $rt_term, $rt_supli).
#######################################
function download() {
    local url=$1
    local isBisem=$2
    local routine_type=$3
    
    local p
    local sems
    local semNo
    local filename
    local file_path
    local output_dir    

    if [ "$isBisem" = "$true" ]; then
        sems="bi"
    elif [ "$isBisem" = "$false" ]; then
        sems="tri"
    else
        sems="unknown"
    fi

    if [ "$routine_type" = "$rt_class" ]; then 
        rt_type="class"
    elif [ "$routine_type" = "$rt_term" ]; then
        rt_type="term"
    elif [ "$routine_type" = "$rt_supli" ]; then
        rt_type="supplementary"     
    else
        rt_type="unknown"
    fi

    progNo=$($URL_PARSER --url "$url" query --query-field="p")
    semNo=$($URL_PARSER --url "$url" query --query-field="semNo" | tr ',' '_')
    
    if [ -n "$semNo" ]; then
        file_path="$semNo"
        filename="$progNo.html"
    else
        if [ "$(is_substr "$url" '.pdf')" = "$true" ]; then
            file_path="pdfs"
        elif [ "$(is_substr "$url" '.docx')" = "$true" ]; then
            file_path="docx"
        else 
            file_path="unknown"
        fi
        
        filename=$($URL_PARSER --url $url path | rev | cut -d '/' -f 1 | rev)
    fi

    output_dir="$DUMP_ROOT_DIR/$rt_type/$sems/$file_path"

    mkdir -p $output_dir

    curl "$url" -so "$output_dir/$filename"
    local res=$?
    if test "$res" != "0"; then
        log "ERROR" "the curl command failed with: $res"
    fi
}

#######################################
# Updates class routine.
#
# Arguments:
#   first param  - xpath expression.
#   second param - whether semester is Bisemester ($true or $false).
#   third param  - routine type ($rt_class, $rt_term, $rt_supli).
#######################################
function update_class() {
    local xpath=$1
    local isBisem=$2
    local routine_type=$3
    
    local row
    local rows=$($XIDEL -se "count($xpath)" $RT_FILE)
    
    local program_name
    local routine_link
    
    local start=$(date +%s)

    for(( row=1; row<=rows; ++row )) 
    do
        program_name=$($XIDEL -se "$xpath[$row]//td[2]" $RT_FILE)
        routine_link=$($XIDEL -se "$xpath[$row]//td[3]//a[1]/@href" $RT_FILE)
        
        log "INFO" "Processing Program: $program_name"
        log "INFO" "Routine url: $routine_link"
        local  _start=$(date +%s)
        download "$routine_link" "$true" "$routine_type"
        local _end=$(date +%s)      
        log "INFO" "Downloaded routine ($((_end-_start))s)"
        log "INFO" "Sleeping for 2s"
        sleep 2
    done

    local end=$(date +%s)
    log "INFO" "Finished everything in ($((end-start))s)"
}


#######################################
# Updates exam routine.
#
# Arguments:
#   first param  - xpath expression.
#   second param  - routine type ($rt_class, $rt_term, $rt_supli).
#######################################
function update_exam() {
    local xpath=$1
    local routine_type=$2
    
    local row
    local rows=$($XIDEL -se "count($xpath)" $RT_FILE)
    
    local program_name
    local routine_link
    
    local start=$(date +%s)
    
    log "INFO" "$($XIDEL -se "$xpath/../../../../../div//h2" $RT_FILE)"
    for(( row=1; row<=rows; ++row )) 
    do
        program_name=$($XIDEL -se "$xpath[$row]//td[1]" $RT_FILE)
        routine_link=$($XIDEL -se "$xpath[$row]//td[2]//a[1]/@href" $RT_FILE)

        if [ $(is_substr "$routine_link" "../../") = $true ];then 
            routine_link="${routine_link/"../../"/"https://classic.bubt.edu.bd/"}"   
        fi
        
        log "INFO" "Processing Program: $program_name"
        log "INFO" "Routine url: $routine_link"
        local  _start=$(date +%s)
        download "$routine_link" "none" "$routine_type"
        local _end=$(date +%s)      
        log "INFO" "Downloaded routine ($((_end-_start))s)"
        log "INFO" "Sleeping for 2s"
        sleep 2
    done

    local end=$(date +%s)
    log "INFO" "Finished everything in ($((end-start))s)"
}



if [ "$1" = "push" ];then
    push_update
elif [ "$1" = "update-bi" ]; then
    update_class "$bisem_cls_expr" "$true" "$rt_class"
elif [ "$1" = "update-tri" ]; then
    update_class "$trisem_cls_expr" "$false" "$rt_class"
elif [ "$1" = "update-term" ]; then
    update_exam "$exam_expr" "$rt_term"
elif [ "$1" = "update-suppli" ]; then
    update_exam "$suppli_expr" "$rt_supli"
fi
