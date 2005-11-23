# /packages/intranet-timesheet2-invoices/www/new-3.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    Receives the list of tasks to invoice and creates an invoice form
    similar to /intranet-invoicing/www/new in order to create a new
    invoice.<br>
    @param include_task A list of im_timesheet_task IDs to include in the
           new invoice
    @param company_id All include_tasks need to be from the same
           company.
    @param invoice_currency: EUR or USD

    @author frank.bergmann@project-open.com
} {
    include_task:multiple
    company_id:integer
    invoice_currency
    invoice_hour_type
    target_cost_type_id:integer
    { return_url ""}
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set org_company_id $company_id

if {"" == $return_url} {set return_url [im_url_with_query] }
set todays_date [db_string get_today "select sysdate from dual"]
set page_focus "im_header_form.keywords"
set view_name "invoice_tasks"

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"
set required_field "<font color=red size=+1><B>*</B></font>"

set number_format "99990.099"
set cost_type_invoice [im_cost_type_invoice]

if {![im_permission $user_id add_invoices]} {
    ad_return_complaint "[_ intranet-timesheet2-invoices.lt_Insufficient_Privileg]" "
    <li>[_ intranet-timesheet2-invoices.lt_You_dont_have_suffici]"    
}

# ---------------------------------------------------------------
# Gather invoice data
# ---------------------------------------------------------------

# Build the list of selected tasks ready for invoicing
set in_clause_list [list]
foreach selected_task $include_task {
    lappend in_clause_list $selected_task
}
set tasks_where_clause "task_id in ([join $in_clause_list ","])"

# We already know that all tasks are from the same company,
# and we asume that the company_id is set from new-2.tcl.

# Create the default values for a new invoice.
#
# Calculate the next invoice number by calculating the maximum of
# the "reasonably build numbers" currently available

set button_text "[_ intranet-timesheet2-invoices.Create_Invoice]"
set page_title "[_ intranet-timesheet2-invoices.New_Invoice]"
set context_bar [im_context_bar [list /intranet/invoices/ "[_ intranet-timesheet2-invoices.Invoices]"] $page_title]
set invoice_id [im_new_object_id]
set invoice_nr [im_next_invoice_nr -invoice_type_id $target_cost_type_id]
set invoice_date $todays_date
set payment_days [ad_parameter -package_id [im_package_cost_id] "DefaultCompanyInvoicePaymentDays" "" 30] 
set due_date [db_string get_due_date "select to_date(to_char(sysdate,'YYYY-MM-DD'),'YYYY-MM-DD') + $payment_days from dual"]
set provider_id [im_company_internal]
set customer_id $company_id

set cost_type_id $target_cost_type_id

set cost_status_id [im_cost_status_created]
set vat 0
set tax 0
set note ""
set payment_method_id ""
set template_id ""


# ---------------------------------------------------------------
# Gather company data from company_id
# ---------------------------------------------------------------

db_1row invoices_info_query "
select 
	c.*,
        o.*,
	im_email_from_user_id(c.accounting_contact_id) as company_contact_email,
	im_name_from_user_id(c.accounting_contact_id) as  company_contact_name,
	c.company_name,
	c.company_path,
	c.company_path as company_short_name,
        cc.country_name
from
	im_companies c, 
        im_offices o,
        country_codes cc
where 
        c.company_id = :company_id
        and c.main_office_id=o.office_id(+)
        and o.address_country_code=cc.iso(+)
"

# ---------------------------------------------------------------
# 6. Select and render invoicable items 
# ---------------------------------------------------------------

set sql "
select 
	t.task_id,
	t.planned_units,
	t.billable_units,
	t.reported_units_cache,
	t.task_name,
	t.uom_id,
	t.task_type_id,
	t.project_id,
	im_category_from_id(t.uom_id) as uom_name,
	im_category_from_id(t.task_type_id) as type_name,
	im_category_from_id(t.task_status_id) as task_status,
	p.project_name,
	p.project_path,
	p.project_path as project_short_name
from 
	im_timesheet_tasks t,
	im_projects p
where 
	$tasks_where_clause
	and t.project_id = p.project_id
order by
	project_id, task_id
"

set task_table "
<tr> 
  <td class=rowtitle>[_ intranet-timesheet2-invoices.Task_Name]</td>
  <td class=rowtitle>[_ intranet-timesheet2-invoices.Planned_Units]</td>
  <td class=rowtitle>[_ intranet-timesheet2-invoices.Billable_Units]</td>
  <td class=rowtitle>[_ intranet-timesheet2-invoices.Reported_Units]</td>
  <td class=rowtitle>[_ intranet-timesheet2-invoices.UoM] [im_gif help "Unit of Measure"]</td>
  <td class=rowtitle>[_ intranet-timesheet2-invoices.Type]</td>
  <td class=rowtitle>[_ intranet-timesheet2-invoices.Status]</td>
</tr>
"
set planned_checked ""
set billable_checked ""
set reported_checked ""
switch $invoice_hour_type {
    planned { set planned_checked " checked" }
    billable { set billable_checked " checked" }
    reported { set reported_checked " checked" }
}

append task_table "
<tr>
  <td>Billing hour type:</td>
  <td align=center><input type=radio name=invoice_hour_type value=planned disabled $planned_checked></td>
  <td align=center><input type=radio name=invoice_hour_type value=billable disabled $billable_checked></td>
  <td align=center><input type=radio name=invoice_hour_type value=reported disabled $reported_checked></td>
  <td></td>
  <td></td>
  <td></td>
</tr>
"

ns_log Notice "before rendering the task list $invoice_id"

set task_table_rows ""
set ctr 0
set colspan 7
set old_project_id 0
db_foreach select_tasks $sql {

    # insert intermediate headers for every project
    if {$old_project_id != $project_id} {
	append task_table_rows "
		<tr><td colspan=$colspan>&nbsp;</td></tr>
		<tr>
		  <td class=rowtitle colspan=$colspan>
	            <A href=/intranet/projects/view?project_id=$project_id>
		      $project_short_name
		    </A>: $project_name
	          </td>
		  <input type=hidden name=select_project value=$project_id>
		</tr>\n"
	set old_project_id $project_id
    }

    append task_table_rows "
        <input type=hidden name=im_timesheet_task value=$task_id>
	<tr $bgcolor([expr $ctr % 2])> 
	  <td align=left>$task_name</td>
	  <td align=right>$planned_units</td>
	  <td align=right>$billable_units</td>
	  <td align=right>$reported_units_cache</td>
	  <td align=right>$uom_name</td>
	  <td>$type_name</td>
	  <td>$task_status</td>
	</tr>"
    incr ctr
}

if {![string equal "" $task_table_rows]} {
    append task_table $task_table_rows
} else {
    append task_table "<tr><td colspan=$colspan align=center>[_ intranet-timesheet2-invoices.No_tasks_found]</td></tr>"
}

# ---------------------------------------------------------------
# 7. Select and format the sum of the invoicable items
# for a new invoice
# ---------------------------------------------------------------

    # start formatting the list of sums with the header...
    set task_sum_html "
        <tr align=center> 
          <td class=rowtitle>[_ intranet-timesheet2-invoices.Order]</td>
          <td class=rowtitle>[_ intranet-timesheet2-invoices.Description]</td>
          <td class=rowtitle>[_ intranet-timesheet2-invoices.Units]</td>
          <td class=rowtitle>[_ intranet-timesheet2-invoices.UOM]</td>
          <td class=rowtitle>[_ intranet-timesheet2-invoices.Rate]</td>
        </tr>
    "

    # Start formatting the "reference price list" as well, even though it's going
    # to be shown at the very bottom of the page.
    #
    set price_colspan 11
    set reference_price_html "
        <tr><td align=middle class=rowtitle colspan=$price_colspan>[_ intranet-timesheet2-invoices.Reference_Prices]</td></tr>
        <tr>
          <td class=rowtitle>[_ intranet-timesheet2-invoices.Company]</td>
          <td class=rowtitle>[_ intranet-timesheet2-invoices.UoM]</td>
          <td class=rowtitle>[_ intranet-timesheet2-invoices.Task_Type]</td>
          <td class=rowtitle>[_ intranet-timesheet2-invoices.Material]</td>
<!--          <td class=rowtitle>[_ intranet-timesheet2-invoices.Valid_From]</td>	-->
<!--          <td class=rowtitle>[_ intranet-timesheet2-invoices.Valid_Through]</td>	-->
          <td class=rowtitle>[_ intranet-timesheet2-invoices.Price]</td>
        </tr>\n"


    # Calculate the sum of tasks (distinct by TaskType and UnitOfMeasure)
    # and determine the price of each line using a custom definable
    # function.
    set task_sum_inner_sql "
select
	sum(t.planned_units) as planned_sum,
	sum(t.billable_units) as billable_sum,
	sum(t.reported_units_cache) as reported_sum,
	t.task_type_id,
	t.uom_id,
	p.company_id,
	p.project_id,
	t.material_id
from 
	im_timesheet_tasks t,
	im_projects p
where 
	$tasks_where_clause
	and t.project_id=p.project_id
group by
	t.material_id,
	t.task_type_id,
	t.uom_id,
	p.company_id,
	p.project_id
"


    # Calculate the price for the specific service.
    # Complicated undertaking, because the price depends on a number of variables,
    # depending on client etc. As a solution, we act like a search engine, return 
    # all prices and rank them according to relevancy. We take only the first 
    # (=highest rank) line for the actual price proposal.
    #
    set reference_price_sql "
select 
	p.relevancy as price_relevancy,
	trim(' ' from to_char(p.price,:number_format)) as price,
	p.company_id as price_company_id,
	p.uom_id as uom_id,
	p.task_type_id as task_type_id,
	p.material_id as material_id,
	p.valid_from,
	p.valid_through,
	c.company_path as price_company_name,
        im_category_from_id(p.uom_id) as price_uom,
        im_category_from_id(p.task_type_id) as price_task_type,
        im_category_from_id(p.material_id) as price_material
from
	(
		(select 
			im_timesheet_prices_calc_relevancy (
				p.company_id,:company_id,
				p.task_type_id, :task_type_id,
				p.material_id, :material_id
			) as relevancy,
			p.price,
			p.company_id,
			p.uom_id,
			p.task_type_id,
			p.material_id,
			p.valid_from,
			p.valid_through
		from im_timesheet_prices p
		where
			uom_id=:uom_id
			and currency=:invoice_currency
		)
	) p,
	im_companies c
where
	p.company_id=c.company_id
	and relevancy >= 0
order by
	p.relevancy desc,
	p.company_id,
	p.uom_id
    "


    set ctr 1
    set old_project_id 0
    set colspan 6
    db_foreach task_sum "" {

	set task_sum 0
	switch $invoice_hour_type {
	    planned { set task_sum $planned_sum }
	    billable { set task_sum $billable_sum }
	    reported { set task_sum $reported_sum }
	}

	# insert intermediate headers for every project
	if {$old_project_id != $project_id} {
	    append task_sum_html "
		<tr><td class=rowtitle colspan=$price_colspan>
	          <A href=/intranet/projects/view?project_id=$project_id>$project_short_name</A>:
	          $project_nr
	        </td></tr>\n"

	    # Also add an intermediate header to the price list
	    append reference_price_html "
		<tr><td class=rowtitle colspan=$price_colspan>
	          <A href=/intranet/projects/view?project_id=$project_id>$project_short_name</A>:
	          $project_nr
	        </td></tr>\n"
	
	    set old_project_id $project_id
	}

	# Determine the price from a ranked list of "price list hits"
	# and render the "reference price list"
	set price_list_ctr 1
	set best_match_price 0
	db_foreach references_prices $reference_price_sql {

	    ns_log Notice "new-3: company_id=$company_id, uom_id=$uom_id => price=$price, relevancy=$price_relevancy"
	    # Take the first line of the result list (=best score) as a price proposal:
	    if {$price_list_ctr == 1} {set best_match_price $price}

	    append reference_price_html "
        <tr>
          <td class=$bgcolor([expr $price_list_ctr % 2])>$price_company_name</td>
          <td class=$bgcolor([expr $price_list_ctr % 2])>$price_uom</td>
          <td class=$bgcolor([expr $price_list_ctr % 2])>$price_task_type</td>
          <td class=$bgcolor([expr $price_list_ctr % 2])>$price_material</td>
<!--          <td class=$bgcolor([expr $price_list_ctr % 2])>$valid_from</td>		-->
<!--          <td class=$bgcolor([expr $price_list_ctr % 2])>$valid_through</td> 	-->
          <td class=$bgcolor([expr $price_list_ctr % 2])>$price $invoice_currency</td>
        </tr>\n"
	
	    incr price_list_ctr
	}

	# Add an empty line to the price list to separate prices form item to item
	append reference_price_html "<tr><td colspan=$price_colspan>&nbsp;</td></tr>\n"

	append task_sum_html "
	<tr $bgcolor([expr $ctr % 2])> 
          <td>
	    <input type=text name=item_sort_order.$ctr size=2 value='$ctr'>
	  </td>
          <td>
	    <input type=text name=item_name.$ctr size=40 value='$material_name'>
	  </td>
          <td align=right>
	    <input type=text name=item_units.$ctr size=4 value='$task_sum'>
	  </td>
          <td align=right>
	    <input type=hidden name=item_uom_id.$ctr value='$uom_id'>
	    $task_uom
	  </td>
          <td align=right>
	    <input type=text name=item_rate.$ctr size=3 value='$best_match_price'>
	    <input type=hidden name=item_currency.$ctr value='$invoice_currency'>
	    $invoice_currency
	  </td>
        </tr>
	<input type=hidden name=item_project_id.$ctr value='$project_id'>
	<input type=hidden name=item_type_id.$ctr value='$task_type_id'>\n"

	incr ctr
    }


# ---------------------------------------------------------------
# 10. Join all parts together
# ---------------------------------------------------------------

set include_task_html ""
foreach task_id $in_clause_list {
    append include_task_html "<input type=hidden name=include_task value=$task_id>\n"
}

db_release_unused_handles

ad_return_template