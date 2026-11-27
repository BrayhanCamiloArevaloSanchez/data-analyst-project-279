--last_paid_click
with paid_visits as (
	select
		visitor_id,
		visit_date,
		source,
		medium,
		campaign
	from sessions
	where medium in (
				'cpc',
				'cpm',	
				'cpa',
				'youtube',
				'cpp',
				'tg',
				'social'
	)
),

last_leads as (
	select * from (
		select
			visitor_id,
            lead_id,
            created_at,
            amount,
            closing_reason,
            status_id,
            row_number () over (
            	partition by visitor_id
            	order by created_at desc
            ) as row_num
     from leads
	) as ranked_lead
	where row_num = 1 
),

lead_clicks as (
	select 
		visitor_id,
	    visit_date,
	    source,
	    medium,
	    campaign,
	    lead_id,
	    created_at,
	    amount,
	    closing_reason,
	    status_id
	from (
			select
				pv.visitor_id,
		        pv.visit_date,
		        pv.source,
		        pv.medium,
		        pv.campaign,
		        ll.lead_id,
		        ll.created_at,
		        ll.amount,
		        ll.closing_reason,
		        ll.status_id,
		        row_number () over (
		        	partition by pv.visitor_id
		        	order by pv.visit_date desc
		        ) as row_num
	     from paid_visits pv
	     inner join last_leads ll
	     	on pv.visitor_id = ll.visitor_id
	        and ll.created_at >= pv.visit_date
	     ) as ranked_lead_clicks
     where row_num = 1
),
     
not_lead_clicks as (
	select
		pv.visitor_id,
		pv.visit_date,
		pv.source,
		pv.medium,
		pv.campaign,
		null::text as lead_id,
		null::timestamp as created_at,
		null::numeric as amount,
		null::text as closing_reason,
		null::integer as status_id
	from paid_visits pv
	left join last_leads ll
		on pv.visitor_id = ll.visitor_id
	where ll.visitor_id IS NULL
	),
	
all_clicks as (
	
	select 
		visitor_id,
	    visit_date,
	    source,
	    medium,
	    campaign,
	    lead_id,
	    created_at,
	    amount,
	    closing_reason,
	    status_id
	from lead_clicks
	
	union all
	
	select 
		visitor_id,
	    visit_date,
	    source,
	    medium,
	    campaign,
	    lead_id,
	    created_at,
	    amount,
	    closing_reason,
	    status_id
	from not_lead_clicks
)

	
select 
	visitor_id,
    visit_date,
    source as utm_source,
    medium as utm_medium,
    campaign as utm_campaign,
    lead_id,
    created_at,
    amount,
    case
    	when closing_reason = 'successful_sale' then 'Venta exitosa'
        when closing_reason = 'not_realized' then 'No concretada'
    	when closing_reason = 'in_progress' then 'En proceso'
    end as closing_reason,
    status_id
from all_clicks
order by amount desc nulls last, 
		 visit_date asc,
		 utm_source asc,
		 utm_medium asc,
         utm_campaign asc;


