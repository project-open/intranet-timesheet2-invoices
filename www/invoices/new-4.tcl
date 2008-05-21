# /packages/intranet-timesheet2-invoices/www/invoices/new-4.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


ad_page_contract {
    Saves invoice changes and set the invoice status to "Created".<br>
    Please note that there are different forms to create invoices for
    example in the intranet-timesheet2-invoicing module of the 
    intranet-server-hosting module.
    @author frank.bergmann@project-open.com
} {
    invoice_id:integer
    customer_id:integer
    provider_id:integer
    { select_project:integer,multiple {} }
    invoice_nr
    invoice_date
    cost_status_id:integer 
    cost_type_id:integer
    cost_center_id:integer
    { company_contact_id "" }
    { invoice_office_id "" }
    { payment_days:integer 0 }
    { payment_method_id:integer "" }
    template_id:integer
    vat:float
    tax:float
    item_sort_order:array
    item_name:array
    item_units:float,array
    item_uom_id:integer,array
    item_type_id:integer,array
    item_project_id:integer,array
    item_rate:float,array
    item_currency:array
    im_timesheet_task:multiple
    { return_url "/intranet-invoices/" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]

if {![im_permission $user_id add_invoices]} {
    ad_return_complaint 1 "<li>[_ intranet-timesheet2-invoices.lt_You_dont_have_suffici]"
    return
}

set write_p [im_cost_center_write_p $cost_center_id $cost_type_id $user_id]
if {!$write_p} {
    ad_return_complaint "Insufficient Privileges" "
        <li>You can't create documents of type \#$cost_type_id in CostCenter \#$cost_center_id."
    ad_script_abort
}


# Look for common super-projects for multi-project documents
set select_project [im_invoices_unify_select_projects $select_project]

set project_id ""
if {1 == [llength $select_project]} {
    set project_id [lindex $select_project 0]
}

# ---------------------------------------------------------------
# Update invoice base data
# ---------------------------------------------------------------

set invoice_exists_p [db_string invoice_count "select count(*) from im_invoices where invoice_id=:invoice_id"]

# Just update the invoice if it already exists:
if {!$invoice_exists_p} {

    # Let's create the new invoice
    db_exec_plsql create_invoice "
	DECLARE
	    v_invoice_id        integer;
	BEGIN
	    v_invoice_id := im_timesheet_invoice.new (
	        invoice_id              => :invoice_id,
	        creation_user           => :user_id,
	        creation_ip             => '[ad_conn peeraddr]',
	        invoice_nr              => :invoice_nr,
	        customer_id             => :customer_id,
	        provider_id             => :provider_id,
	        invoice_date            => :invoice_date,
	        invoice_template_id     => :template_id,
	        invoice_status_id	=> :cost_status_id,
	        invoice_type_id		=> :cost_type_id,
	        payment_method_id       => :payment_method_id,
	        payment_days            => :payment_days,
		amount			=> 0,
	        vat                     => :vat,
	        tax                     => :tax
	    );
	END;"
}

# Update the invoice itself
db_dml update_invoice "
update im_invoices 
set 
	invoice_nr	= :invoice_nr,
        company_contact_id = :company_contact_id,
	payment_method_id = :payment_method_id,
        invoice_office_id = :invoice_office_id
where
	invoice_id = :invoice_id
"

db_dml update_costs "
update im_costs
set
	project_id	= :project_id,
	cost_name	= :invoice_nr,
        cost_nr         = :invoice_id,
	customer_id	= :customer_id,
	provider_id	= :provider_id,
	cost_status_id	= :cost_status_id,
	cost_type_id	= :cost_type_id,
        cost_center_id  = :cost_center_id,
	template_id	= :template_id,
	effective_date	= :invoice_date,
	start_block	= ( select max(start_block) 
			    from im_start_months 
			    where start_block < :invoice_date),
	payment_days	= :payment_days,
	vat		= :vat,
	tax		= :tax,
	variable_cost_p = 't'
where
	cost_id = :invoice_id
"

# ---------------------------------------------------------------
# Create the im_invoice_items for the invoice
# ---------------------------------------------------------------

# Delete the old items if they exist
db_dml delete_invoice_items "
	DELETE from im_invoice_items
	WHERE invoice_id=:invoice_id
"

set item_list [array names item_name]
foreach nr $item_list {
    set name $item_name($nr)
    set units $item_units($nr)
    set uom_id $item_uom_id($nr)
    set type_id $item_type_id($nr)
    set project_id $item_project_id($nr)
    set rate $item_rate($nr)
    set currency $item_currency($nr)
    set sort_order $item_sort_order($nr)
    ns_log Notice "item($nr, $name, $units, $uom_id, $project_id, $rate, $currency)"

    # Insert only if it's not an empty line from the edit screen
    if {!("" == [string trim $name] && (0 == $units || "" == $units))} {
	set item_id [db_nextval "im_invoice_items_seq"]
	set insert_invoice_items_sql "
	INSERT INTO im_invoice_items (
		item_id, item_name, 
		project_id, invoice_id, 
		item_units, item_uom_id, 
		price_per_unit, currency, 
		sort_order, item_type_id, 
		item_status_id, description
	) VALUES (
		:item_id, :name, 
		:project_id, :invoice_id, 
		:units, :uom_id, 
		:rate, :currency, 
		:sort_order, :type_id, 
		null, ''
	)"

        db_dml insert_invoice_items $insert_invoice_items_sql
    }
}

# ---------------------------------------------------------------
# Update the invoice amount based on the invoice items
# ---------------------------------------------------------------

set update_invoice_amount_sql "
update im_costs
set amount = (
	select sum(price_per_unit * item_units)
	from im_invoice_items
	where invoice_id = :invoice_id
	group by invoice_id
)
where cost_id = :invoice_id
"

db_dml update_invoice_amount $update_invoice_amount_sql


# ---------------------------------------------------------------
# Add a relationship to all related projects
# ---------------------------------------------------------------

foreach project_id $select_project {

    catch {db_exec_plsql insert_acs_rels "
	DECLARE
		v_rel_id	integer;
	BEGIN
		v_rel_id := acs_rel.new(
			object_id_one => :project_id,
			object_id_two => :invoice_id
		);
	END;
    "} err_msg
}


# ---------------------------------------------------------------
# Update all invoiced im_timesheet_tasks
# ---------------------------------------------------------------

# only if it's a "real" Invoice - Quotes don't do the job...
# The reason is that we only want to invoice every timesheet2-task
# exactly once.
#
if {$cost_type_id == [im_cost_type_invoice]} {

    db_dml update_timesheet_tasks "
	update	im_timesheet_tasks
	set	invoice_id = :invoice_id
	where	task_id in ([join $im_timesheet_task ","])
    "
}

db_release_unused_handles
ad_returnredirect "/intranet-invoices/view?invoice_id=$invoice_id"
