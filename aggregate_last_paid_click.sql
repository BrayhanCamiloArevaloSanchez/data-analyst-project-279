-- Agregate_last_paid_click
with united_campaign as (
	select 
		campaign_id,
		campaign_name,
		utm_source,
		utm_medium,
		utm_campaign,
		campaign_date,
		daily_spent
	from google_ads
	
	union all
	
	select 
		campaign_id,
		campaign_name,
		utm_source,
		utm_medium,
		utm_campaign,
		campaign_date,
		daily_spent
	from meta_ads
		
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

last_paid_visits AS (
    SELECT
        visitor_id,
        visit_date,
        source,
        medium,
        campaign
    FROM (
        SELECT
            visitor_id,
            visit_date,
            source,
            medium,
            campaign,
            ROW_NUMBER() OVER (
                PARTITION BY visitor_id
                ORDER BY visit_date DESC
            ) AS row_num
        FROM paid_visits
    ) AS ranked_visits
    WHERE row_num = 1
),

attributed_leads AS (
    SELECT
        lp.visitor_id,
        lp.visit_date,
        lp.source,
        lp.medium,
        lp.campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM last_paid_visits lp
    INNER JOIN leads l
        ON lp.visitor_id = l.visitor_id
       AND l.created_at >= lp.visit_date
),

visitors_count as (
	select
		visit_date::date as visit_date,
        source,
        medium,
        campaign,
        COUNT (distinct visitor_id) as visitors_count
    from last_paid_visits
    group by 
    	visit_date::date,
    	source,
    	medium,
    	campaign
	),

leads_succesfull as (
	select 
		lead_id,
        visit_date,
        source,
        medium,
        campaign,
        amount
	from attributed_leads
where closing_reason = 'successful_sale'
or status_id = 142
),

leads_count as (
	select 
        	visit_date::date AS visit_date,
        	source,
        	medium,
        	campaign,   
        	COUNT (lead_id) as leads_count
    from attributed_leads
    group by 
    	visit_date::date,
    	source,
    	medium,
    	campaign		
),

purchases as (
	 select
        visit_date::date AS visit_date,
        source,
        medium,
        campaign,
        COUNT(lead_id) as purchases_count,
        SUM(amount) as revenue
    from leads_succesfull
    group by
        visit_date::date,
        source,
        medium,
        campaign
)


SELECT
    vc.visit_date,
    vc.visitors_count,
    vc.source AS utm_source,
    vc.medium AS utm_medium,
    vc.campaign AS utm_campaign,
    ac.total_cost AS total_cost,
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
