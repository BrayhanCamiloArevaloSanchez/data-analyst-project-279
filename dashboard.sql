with united_campaign as (
	select 
		campaign_id,
		campaign_name,
		utm_source,
		utm_medium,
		utm_campaign,
		campaign_date,
		daily_spent
	from ya_ads
	
	union all
	
	select 
		campaign_id,
		campaign_name,
		utm_source,
		utm_medium,
		utm_campaign,
		campaign_date,
		daily_spent
	from vk_ads
		
),

add_cost as (
	select
		campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM (daily_spent) as total_cost
    from united_campaign
    group by
        campaign_date,
    	utm_source,
        utm_medium,
        utm_campaign
        
),

paid_visits as (
	select 
		visitor_id,
		visit_date::date as visit_date,
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

visitors_count as (
	select
		visit_date,
        source,
        medium,
        campaign,
        COUNT (visitor_id) AS visitors_count
    from paid_visits
    group by 
    	visit_date,
    	source,
    	medium,
    	campaign
	),

last_click as (
	select * from (
		select 
			pv.visitor_id,
			pv.visit_date,
			pv.source,
			pv.medium,
			pv.campaign,
			l.lead_id,
			l.created_at,
			l.amount,
			l.closing_reason,
			l.status_id,
			row_number () over (
				partition by l.lead_id
				order by pv.visit_date desc 
			) as row_num
		from paid_visits pv
		inner join leads l
		on pv.visitor_id = l.visitor_id
		and l.created_at >= pv.visit_date		
	) as ranked_last_click
where row_num = 1
),

leads_succesfull as (
	select 
		lead_id,
        visit_date,
        source,
        medium,
        campaign,
        amount
	from last_click
where closing_reason = 'Успешная продажа'
or status_id = 142
),

leads_count as (
	select 
        	visit_date,
        	source,
        	medium,
        	campaign,   
        	COUNT (lead_id) as leads_count
    from leads_succesfull
    group by 
    	visit_date,
    	source,
    	medium,
    	campaign		
),

purchases as (
	 select
        visit_date,
        source,
        medium,
        campaign,
        COUNT(lead_id) as purchases_count,
        SUM(amount) as revenue
    from leads_succesfull
    group by
        visit_date,
        source,
        medium,
        campaign
)

--select * from add_cost;

SELECT
    vc.visit_date,
    vc.visitors_count,
    vc.source AS utm_source,
    vc.medium AS utm_medium,
    vc.campaign AS utm_campaign,
    COALESCE(ac.total_cost, 0) AS total_cost,
    COALESCE(lc.leads_count, 0) AS leads_count,
    COALESCE(p.purchases_count, 0) AS purchases_count,
    COALESCE(p.revenue, 0) AS revenue
FROM visitors_count vc

LEFT JOIN leads_count lc
    ON vc.visit_date = lc.visit_date
    AND vc.source = lc.source
    AND vc.medium = lc.medium
    AND vc.campaign = lc.campaign

LEFT JOIN purchases p
    ON vc.visit_date = p.visit_date
    AND vc.source = p.source
    AND vc.medium = p.medium
    AND vc.campaign = p.campaign

LEFT JOIN add_cost ac
    ON vc.visit_date = ac.campaign_date
    AND vc.source = ac.utm_source
    AND vc.medium = ac.utm_medium
    AND vc.campaign = ac.utm_campaign

ORDER BY
    revenue DESC NULLS LAST,
    visit_date ASC,
    visitors_count DESC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC;
