# /packages/intranet-timesheet2-invoices/download-prices.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_page_contract {
    Export the current priclist of a company in CSV format
    suitable to be re-imported via upload.

    Let's pray that neither company_path, material_nr nor project_nr
    contain the ";" (or ",", LibreOffice messes up CSV!) CSV separator.
    @author frank.bergmann@project-open.com
} {
    return_url:notnull
    company_id:integer
    { mime_type "application/csv" }
}

set user_id [auth::require_login]
set company [db_string company_path "select c.company_path from im_companies c where c.company_id = :company_id"]

set price_sql "
	select
		tp.*,
		im_category_from_id(tp.uom_id) as uom,
		to_char(tp.valid_from, 'YYYY-MM-DD') as valid_from,
		to_char(tp.valid_through, 'YYYY-MM-DD') as valid_through,
		to_char(tp.valid_from, 'J') as valid_from_julian,
		to_char(tp.valid_through, 'J') as valid_through_julian,
		im_material_nr_from_id(tp.material_id) as material,
		(select p.project_nr from im_projects p where p.project_id = tp.project_id) as project,
		im_category_from_id(tp.task_type_id) as task_type
	from
		im_timesheet_prices tp
	where 
		tp.company_id = :company_id
	order by
		tp.currency,
		coalesce(tp.uom_id, 0),
		coalesce(tp.project_id, 0),
		coalesce(tp.material_id, 0),
		coalesce(tp.valid_from, '2000-01-01'::date),
		coalesce(tp.valid_through, '2100-01-01'::date),
		coalesce(tp.task_type_id, 0),
		tp.price_id
"

# List of columns, also used to calculate the value lines
set var_list {uom company project material task_type price currency valid_from valid_through}

# The header of the CSV
set csv_header_line [list]
foreach var $var_list { lappend csv_header_line $var }

set csv_lines [list [join $csv_header_line ";"] ""]
db_foreach prices $price_sql {
    set csv_line_vals [list]
    foreach var $var_list {
	lappend csv_line_vals [set $var]
    }
    lappend csv_lines [join $csv_line_vals ";"]
}

set csv [join $csv_lines "\n"]
doc_return 200 $mime_type $csv
