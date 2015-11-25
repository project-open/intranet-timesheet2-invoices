<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">@context_bar;literal@</property>
<property name="main_navbar_label">finance</property>
<property name="sub_navbar">@costs_navbar_html;literal@</property>
<property name="left_navbar">@left_navbar_html;literal@</property>

<form method=POST action='new-2'>
<%= [export_vars -form {target_cost_type_id}] %>
<table class="table_list_page" width="100%" cellpadding="2" cellspacing="2" border="0">
	@table_header_html;noquote@
	@table_body_html;noquote@
	@table_continuation_html;noquote@
	@submit_button;noquote@
</table>
</form>
