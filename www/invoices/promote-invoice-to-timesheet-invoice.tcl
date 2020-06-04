# /packages/intranet-timesheet2-invoices/www/invoices/promote-invoice-to-timesheet-invoice.tcl
#
# Copyright (c) 2003-2020 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


ad_page_contract {
    Takes a normal invoice and adds the meta-information to make it
    a timesheet invoice (which contains service start- and end).
    @author frank.bergmann@project-open.com
} {
    invoice_id:integer
    { return_url "/intranet-invoices/" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [auth::require_login]
set outline_number_enabled_p [im_column_exists im_invoice_items item_outline_number]
im_invoice_permissions $current_user_id $invoice_id view read write admin
if {!$write} {
    ad_return_complaint 1 "<li>[_ intranet-timesheet2-invoices.lt_You_dont_have_suffici]"
    ad_script_abort
}



# ---------------------------------------------------------------
# Promote
# ---------------------------------------------------------------


im_timesheet_invoice_promote_invoice -invoice_id $invoice_id



# ---------------------------------------------------------------
# Where do you want to go now?
# ---------------------------------------------------------------

ad_returnredirect "/intranet-invoices/view?invoice_id=$invoice_id"
