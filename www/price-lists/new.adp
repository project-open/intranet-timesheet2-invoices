<master src="../../../intranet-core/www/master">
<property name="doc(title)">@page_title;literal@</property>
<property name="context">@context;literal@</property>
<property name="main_navbar_label">finance</property>
<property name="focus">@focus;literal@</property>

<!-- Show calendar on start- and end-date -->
<script type="text/javascript" <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce;literal@"</if>>
window.addEventListener('load', function() { 
     document.getElementById('valid_from_calendar').addEventListener('click', function() { showCalendarWithDateWidget('valid_from', 'y-m-d'); });
     document.getElementById('valid_through_calendar').addEventListener('click', function() { showCalendarWithDateWidget('valid_through', 'y-m-d'); });
});
</script>

<h2>@page_title@</h2>
<if @message@ not nil>
  <div class="general-message">@message@</div>
</if>

<formtemplate id="price"></formtemplate>

