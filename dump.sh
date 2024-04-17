#!/bin/bash

# Configs

# ~~~~ dirs ~~~~
BIN_DIR="bin"
DUMP_ROOT_DIR="routines"
# ~~~~      ~~~~

# ~~~~ binary files ~~~~
XIDEL="./${BIN_DIR}/xidel"
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
bisem_cls_expr="//div[@id='Bi_Class_Routine']//table//tbody//tr"
trisem_cls_expr="//div[@id='Tri_Class_Routine']//table//tbody//tr"
# ~~~~             ~~~~

FILENAME="routine.html"

# end Configs


function is_substr() { 
	if [[ $1 = *"$2"* ]]; then
        echo $true
    else
    	echo $false
    fi
}


function dl_file() {
	local url=$1
	local isBisem=$2
	local routine_type=$3
	
	local p
	local semNo
	local filename
	local file_path
	local output_dir	

	if [ "$isBisem" = "$true" ]; then
	  	sems="bi"
	else
		sems="tri"
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

	p=$($URL_PARSER --url $routine_link query --query-field=p)
	semNo=$($URL_PARSER --url $routine_link query --query-field=semNo | tr ',' '_')
	
	if [ -n "$semNo" ]; then
		file_path="$semNo"
		filename="$p.html"
	else
		if [ "$(is_substr $url '.pdf')" = "$true" ]; then
			file_path="pdfs"
		elif [ "$(is_substr $url '.docx')" = "$true" ]; then
			file_path="docx"
		else 
			file_path="unknown"
		fi
		
		filename=$($URL_PARSER --url $url path | rev | cut -d '/' -f 1 | rev)
	fi

	output_dir="$DUMP_ROOT_DIR/$rt_type/$sems/$file_path"

	mkdir -p $output_dir

	curl "$url" -so "$output_dir/$filename"
	res=$?
	if test "$res" != "0"; then
	   echo "the curl command failed with: $res"
	fi
}


function dump() {
	local xpath=$1
	local isBisem=$2
	local routine_type=$3
	
	local rows=$($XIDEL -se "count($xpath)" $FILENAME)

	local program_name
	local routine_link
	
	start=$(date +%s)

	for(( row=1; row<=rows; ++row )) 
	do
		program_name=$($XIDEL -se "$xpath[$row]//td[2]" $FILENAME)
		routine_link=$($XIDEL -se "$xpath[$row]//td[3]//a[1]/@href" $FILENAME)
		
		echo "Processing Program: $program_name"
		echo "Routine url: $routine_link"
		_start=$(date +%s)
		dl_file $routine_link $true $routine_type
		_end=$(date +%s)		
		echo -e "Downloaded routine. ($((_end-_start))s)\n"
		echo -e "\nsleeping for 2s\n"
		sleep 2
	done

	end=$(date +%s)

	echo -e "Finished everything in ($((end-start))s)\n"
}

curl "https://bubt.edu.bd/home/routines" -so routine.html

dump $bisem_cls_expr $true 'class'
# dump $trisem_cls_expr $false 'class'

