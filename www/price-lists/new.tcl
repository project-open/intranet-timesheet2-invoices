# /packages/intranet-timesheet2-invoices/www/price-lists/new.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_page_contract {
    Create or edit an entry in the price list
    @param form_mode edit or display
    @author frank.bergmann@project-open.com
} {
    price_id:integer,optional
    company_id:integer,optional
    {return_url "/intranet/companies/"}
    { currency "" }
    edit_p:optional
    message:optional
    { form_mode "edit" }
}


# ------------------------------------------------------------------
# Default & Security
# ------------------------------------------------------------------

set action_url "new"
set focus "price.var_name"
set page_title "[_ intranet-timesheet2-invoices.New_Price]"
set context [im_context_bar $page_title]
set user_id [auth::require_login]
if {"" == $currency} { set currency [im_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"] }


# In general we need financial permissions to read, modify or create prices.
if {![im_permission $user_id add_finance]} {
    ad_return_complaint 1 "[_ intranet-timesheet2-invoices.lt_You_have_insufficient_1]"
    ad_script_abort
}

# Get the company_id if the price_id exists
if {[info exists price_id] && ![info exists company_id]} {
    db_1row price_info "
	select	company_id
	from	im_timesheet_prices
	where	price_id = :price_id           
    "
}

# We always need a company to determine permissions on prices
# For display/edit of existing prices, we got the company from the price_id above.
# For new prices, the user needs to specify the company_id in the URL parameters.
if {![info exists company_id]} { 
    ad_return_complaint 1 "You need to specify 'company_id'"
    ad_script_abort
}

# Check if the user is allowed to create a new price
im_company_permissions $user_id $company_id view read write admin
if {!$write || ![im_permission $user_id add_finance]} {
    ad_return_complaint 1 "[_ intranet-timesheet2-invoices.lt_You_have_insufficient_1]"
    ad_script_abort
}


# ------------------------------------------------------------------
# Build the form
# ------------------------------------------------------------------

set uom_options [im_cost_uom_options]
set task_type_options [db_list_of_lists uom "select category, category_id from im_categories where category_type = 'Intranet Project Type'"]
set task_type_options [linsert $task_type_options 0 [list "" ""]]
set material_options [im_material_options -include_empty 1]
set project_options [im_project_options -include_empty 1]
set currency_options [im_currency_options 0]

ad_form \
    -name price \
    -cancel_url $return_url \
    -action $action_url \
    -mode $form_mode \
    -export {next_url user_id return_url} \
    -form {
	price_id:key(im_timesheet_prices_seq)
	{company_id:text(hidden)}
	{uom_id:text(select) {label "[_ intranet-timesheet2-invoices.Unit_of_Measure]"} {options $uom_options} }
	{task_type_id:text(im_category_tree),optional {label "[_ intranet-timesheet2-invoices.Task_Type]"} {custom {category_type "Intranet Project Type" translate_p 1 include_empty_p 1}} }
	{material_id:text(select),optional {label "[_ intranet-timesheet2-invoices.Material]"} {options $material_options} }
	{project_id:text(select),optional {label "[_ intranet-core.Project]"} {options $project_options} }
	{valid_from:date(date),optional {label "[_ intranet-timesheet2.Start_Date]"} {after_html {<input id=valid_from_calendar type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');" >}} }
	{valid_through:date(date),optional {label "[_ intranet-timesheet2.End_Date]"} {after_html {<input id=valid_through_calendar type="button" style="height:23px; width:23px; background: url('/resources/acs-templating/calendar.gif');">}} }
	{price:text(text) {label "[_ intranet-timesheet2-invoices.Price]"} {html {size 10}}}
	{currency:text(select) {label "[_ intranet-timesheet2-invoices.Currency]"} {options $currency_options} }
    }


ad_form -extend -name price -on_request {
    # Populate elements from local variables
} -select_query {
	select	p.*
	from	im_timesheet_prices p
	where	p.price_id = :price_id
} -new_data {

    set valid_from_sql [template::util::date get_property sql_date $valid_from]
    set valid_through_sql [template::util::date get_property sql_timestamp $valid_through]

    db_dml price_insert "
	insert into im_timesheet_prices (
		price_id,
		uom_id,
		company_id,
		task_type_id,
		material_id,
		project_id,
		valid_from,
		valid_through,
		currency,
		price
	) values (
		:price_id,
		:uom_id,
		:company_id,
		:task_type_id,
		:material_id,
		:project_id,
		$valid_from_sql,
		$valid_through_sql,
		:currency,
		:price
	)
    "
} -edit_data {

    set valid_from_sql [template::util::date get_property sql_date $valid_from]
    set valid_through_sql [template::util::date get_property sql_timestamp $valid_through]

    db_dml price_update "
	update im_timesheet_prices set
	        uom_id = :uom_id,
	        company_id = :company_id,
	        task_type_id = :task_type_id,
	        material_id = :material_id,
	        project_id = :project_id,
	        valid_from = $valid_from_sql,
	        valid_through = $valid_through_sql,
	        currency = :currency,
	        price = :price
	where
		price_id = :price_id
    "
} -on_submit {
	ns_log Notice "new1: on_submit"
} -after_submit {
	ad_returnredirect $return_url
}
