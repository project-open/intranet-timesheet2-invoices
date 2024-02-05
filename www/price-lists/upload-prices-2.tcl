# /packages/intranet-timesheet2-invoices/www/upload-prices-2.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_page_contract {
    /intranet/companies/upload-prices-2.tcl
    Read a .csv-file with header titles exactly matching
    the data model and insert the data into im_timesheet_prices
} {
    return_url
    company_id:integer
    upload_file
} 

set current_user_id [auth::require_login]
set page_title [lang::message::lookup "" intranet-timesheet2-invoices.Upload_File "Upload File"]
set page_body "<pre>\n<a HREF=$return_url>[lang::message::lookup "" intranet-timesheet2-invoices.Return_to_company_page "Return to company page"]</a>\n"
set context_bar [im_context_bar [list \
				     "/intranet/customers/" \
				     [lang::message::lookup "" intranet-timesheet2-invoices.Customers Customers] \
				     [lang::message::lookup "" intranet-timesheet2-invoices.Upload_CSV "Upload CSV"]]]

# Get the file from the user.
# number_of_bytes is the upper-limit
set max_n_bytes [im_parameter -package_id [im_package_filestorage_id] MaxNumberOfBytes "" 0]
set tmp_filename [ns_queryget upload_file.tmpfile]
ns_log Notice "upload-prices-2: tmp_filename=$tmp_filename"

im_security_alert_check_tmpnam -location "upload-prices-2.tcl" -value $tmp_filename
if {$max_n_bytes && ([file size $tmp_filename] > $max_n_bytes)} {
    ad_return_complaint 1 "[lang::message::lookup "" intranet-timesheet2-invoices.File_too_large "Your file is larger than the maximum permissible upload size"]: [util_commify_number $max_n_bytes] bytes"
    ad_script_abort
}

# strip off the C:\directories... crud and just get the file name
if {![regexp {([^//\\]+)$} $upload_file match company_filename]} {
    # couldn't find a match
    set company_filename $upload_file
}

if {[regexp {\.\.} $company_filename]} {
    set error [lang::message::lookup "" intranet-timesheet2-invoices.Filename_contains_forbidden_characters "Filename contains forbidden characters"]
    ad_return_complaint 1 $error
    ad_script_abort
}

if {![file readable $tmp_filename]} {
    set err_msg "[lang::message::lookup "" intranet-timesheet2-invoices.Unable_to_read_file "Unable to read the file '%tmp_filename%'."]<br>
[lang::message::lookup "" intranet-timesheet2-invoices.Please_check_permisions "Please check the file permissions or contact your system administrator."]"
    ad_return_complaint 1 $err_msg
    ad_script_abort
}
    
set csv_files_content [im_exec cat $tmp_filename]
set csv_files [split $csv_files_content "\n"]
set csv_files_len [llength $csv_files]
set csv_header [lindex $csv_files 1]
set csv_headers [split $csv_header ";"]

# Check the length of the title line 
set header [string trim [lindex $csv_files 0]]
set header_csv_fields [split $header ";"]
set header_len [llength $header_csv_fields]

append page_body "\n\n"

db_dml delete_old_prices "delete from im_timesheet_prices where company_id=:company_id"

for {set i 1} {$i < $csv_files_len} {incr i} {
    set csv_line [string trim [lindex $csv_files $i]]
    set csv_fields [split $csv_line ";"]
    append page_body "[lang::message::lookup "" intranet-core.Line Line] $i: $csv_line\n"

    # Skip empty lines or line starting with "#"
    if {"" eq [string trim $csv_line]} { continue }
    if {"#" eq [string range $csv_line 0 0]} { continue }


    # Preset values, defined by CSV sheet:
    set uom ""
    set company ""
    set task_type ""
    set material ""
    set valid_from ""
    set valid_through ""
    set price ""
    set currency ""
    set price_company_id $company_id

    for {set j 0} {$j < $header_len} {incr j} {
	set var_name [lindex $header_csv_fields $j]
	set var_value [lindex $csv_fields $j]
	set cmd "set $var_name "
	append cmd "\""
	append cmd $var_value
	append cmd "\""
	ns_log Notice "cmd=$cmd"

	if { [catch {	
	    set result [eval $cmd]
	} err_msg] } {
	    append page_body "<font color=red>$err_msg</font>\n";
        }
#	append page_body "set $var_name '$var_value' : $result\n"
    }

    set uom_id ""
    set task_type_id ""
    set material_id ""

    set errmsg ""
    if {$uom ne ""} {
        set uom_id [db_string get_uom_id "select category_id from im_categories where category_type = 'Intranet UoM' and lower(trim(category)) = lower(trim(:uom))" -default 0]
        if {$uom_id == 0} { append errmsg "<li>Didn't find UoM '$uom'\n" }
    }

    if {$company ne ""} {
	set price_company_id [db_string get_company_id "select company_id from im_companies where lower(trim(company_path)) = lower(trim(:company))" -default 0]
	if {$price_company_id == 0} { append errmsg "<li>Didn't find Company '$company'\n" }
	if {"company_path" eq $company} { append errmsg "<li>Please replace example 'company_path' with the company path of the real company\n" }
	if {$price_company_id != $company_id} { append errmsg "<li>Uploading prices for the wrong company ('$price_company_id' instead of '$company_id')\n" }
    }

    if {$task_type ne ""} {
        set task_type_id [db_string get_uom_id "select category_id from im_categories where category_type='Intranet Project Type' and category=:task_type"  -default 0]
        if {$task_type_id == 0} { append errmsg "<li>Didn't find Task Type '$task_type'\n" }
    }

    if {$material ne ""} {
	set material_id [db_string matid "select material_id from im_materials where lower(trim(material_name)) = lower(trim(:material))"  -default ""]
	if {"" == $material_id} {
	    set material_id [db_string matid "select material_id from im_materials where lower(trim(material_nr)) = lower(trim(:material))"  -default ""]
	}
	if {"" == $material_id} { append errmsg "<li>Didn't find material='$material' neither in name nor number of any material\n" }
    }

    # It doesn't matter whether prices are given in European "," or American "." decimals
    regsub {,} $price {.} price


    # append page_body "[lang::message::lookup "" intranet-core.Line Line] $i: uom_id=$uom_id, price_company_id=$price_company_id, task_type_id=$task_type_id, material_id=$material_id, valid_from=$valid_from, valid_through=$valid_through, price=$price, currency=$currency\n"

    set insert_price_sql "INSERT INTO im_timesheet_prices (
       price_id, uom_id, company_id, task_type_id, material_id,
       valid_from, valid_through, currency, price
    ) VALUES (
       nextval('im_timesheet_prices_seq'), :uom_id, :price_company_id, :task_type_id, :material_id,
       :valid_from, :valid_through, :currency, :price
    )"

    if {$errmsg eq ""} {
	# Execute the insert only if there were no errors
        if { [catch {
             db_dml insert_price $insert_price_sql
        } err_msg] } {
	    append page_body "\n<font color=red>$err_msg</font>\n";
        }
    } else {
	# Otherwise show the list of (conversion) errors
	append page_body "<font color=red>$errmsg</font>"
    }
}

append page_body "\n<a HREF=$return_url>[lang::message::lookup "" intranet-timesheet2-invoices.Return_to_company_page "Return to company page"]</a>\n"

ad_return_template
