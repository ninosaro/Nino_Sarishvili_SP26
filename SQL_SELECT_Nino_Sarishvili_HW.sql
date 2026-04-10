----- TASK1

--- added lower('animation') in where clause 

--1. movies betweeb 2017 2019 rate >1 alphabetically sorted
select title from public.film a
left join public.film_category fc 
on a.film_id = fc.film_id
left join public.category c 
on fc.category_id = c.category_id
where 1=1
and a.release_year  between 2017 and 2019
and lower(c."name") = 'animation'
and a.rental_rate >1
order by title asc


--1.2 cte
WITH address_a AS (
    SELECT 
        s.store_id,
        a.address || COALESCE(a.address2, '') AS address_new
    FROM public.store s
    INNER JOIN public.address a 
        ON a.address_id = s.address_id
)

SELECT 
    aa.address_new,
    aa.store_id,
    SUM(p.amount) AS revenue 
FROM address_a aa


-- I would have used this if I would have to reuse the output columns in other queries


--- 1.3. subquery version
SELECT 
    aa.address_new,
    aa.store_id,
    SUM(p.amount) AS revenue 
FROM (
    SELECT 
        s.store_id,
        a.address || COALESCE(a.address2, '') AS address_new
    FROM public.store s
    INNER JOIN public.address a 
        ON a.address_id = s.address_id
) aa
JOIN public.inventory i 
    ON aa.store_id = i.store_id
JOIN public.rental r 
    ON i.inventory_id = r.inventory_id
JOIN public.payment p 
    ON r.rental_id = p.rental_id
WHERE p.payment_date >= '2017-03-01'  
  AND p.payment_date < '2017-04-30'
GROUP BY 
    aa.address_new, 
    aa.store_id;





-- Corrected the joins and grouped by the store_id from store table

--2.revenue, group by rent 2017 march april address address2 aggregated in a  column
select distinct s.store_id, a.address || COALESCE(a.address2, '') as address, sum(p.amount)
from public.store s
inner join public.address a 
on s.address_id = a.address_id 
inner join public.inventory i 
on i.store_id = s.store_id
inner join public.rental r 
on r.inventory_id = i.inventory_id
inner join public.payment p 
on p.rental_id = r.rental_id

where 1=1
and p.payment_date >= '2017-03-01'  
and p.payment_date < '2017-04-30'
group by s.store_id,
a.address || COALESCE(a.address2, '');


--2.1 CTE version
WITH address_a AS (
	SELECT s.store_id,
	a.address || COALESCE(a.address2, '') AS address_new   --- Combine address lines 1 and 2 into a single field
	FROM public.store s                                           --- COALESCE handles cases where address2 is NULL
	INNER JOIN public.address a ON a.address_id=s.address_id
	)                    

	
SELECT 
	address_new,
	s.store_id,
	SUM(p.amount) AS revenue 
FROM address_a aa                                          --- Called address from our CTE
JOIN public.store s ON aa.store_id = s.store_id
JOIN public.inventory i ON s.store_id = i.store_id
JOIN public.rental r ON i.inventory_id = r.inventory_id
JOIN public.payment p ON r.rental_id = p.rental_id
where p.payment_date >= '2017-03-01'  
and p.payment_date < '2017-04-30'
GROUP BY aa.address_new, s.store_id;

---grouped by actor_id for uniqueness


-- 2.2 subquery version

SELECT 
    aa.address_new,
    s.store_id,
    SUM(p.amount) AS revenue 
FROM (
    SELECT 
        s.store_id,
        a.address || COALESCE(a.address2, '') AS address_new
    FROM public.store s
    INNER JOIN public.address a 
        ON a.address_id = s.address_id
) aa
JOIN public.store s 
    ON aa.store_id = s.store_id
JOIN public.inventory i 
    ON s.store_id = i.store_id
JOIN public.rental r 
    ON i.inventory_id = r.inventory_id
JOIN public.payment p 
    ON r.rental_id = p.rental_id
WHERE p.payment_date >= '2017-03-01'  
  AND p.payment_date < '2017-04-30'
GROUP BY 
    aa.address_new, 
    s.store_id;


--3. fist_name, last_name, count number_of_movies, desc  limit 5


select e.actor_id, e.first_name, e.last_name, count(distinct g.title)
from public.actor e
left join public.film_actor f
on e.actor_id=f.actor_id
left join public.film g
on f.film_id=g.film_id
where g.release_year >= 2015
group by e.actor_id , e.first_name, e.last_name
order by count(distinct g.title) desc
limit 5

--- I solve this task by left join cause I need to retrieve data from the columns of film table
-- would not have used subquery or CTE for this task, would make things complicated and increase the processing time

--4. count drama travel documentary group by year, order by release year, deal with null values:
--  number_of_travel_movies, number_of_documentary_movies
select h.release_year,  
sum(case when j.name = 'Drama' then 1 else 0 end) number_of_drama_movies, 
sum(case when j.name = 'Travel' then 1 else 0 end) number_of_travel_movies,
sum(case when j.name = 'Documentary' then 1 else 0 end) number_of_documentary_movies
from public.film h
left join public.film_category i
on h.film_id=i.film_id
left join public.category j
on i.category_id=j.category_id
group by h.release_year 
order by h.release_year desc

--Explanation max() gives us the ability to turn the rows into the columns, sincerly I dont know any other 
-- alterative to max function and I would love to see if you could suggest any so I can also include it in my toolkits








----- TASK2

--1.Which three employees generated the most revenue in 2017? 
-- staff worked in several stores, show the last store they have worked in
-- if they prcoessed the payment they work in a store
-- take into account only payment_date


-- step one, I need to identify the top three employers by revenue

with top as(

select  s.first_name || ' ' || s.last_name as name, 
s.staff_id,  
sum(p.amount) as revenue

from staff s
left join payment p 
on s.staff_id =p.staff_id
where extract(year from p.payment_date ) = 2017
group by s.first_name || ' ' || s.last_name,
s.staff_id 

order by sum(amount) desc
limit 3
),

--- step two, I need to identify the latest payment by staff id 
--- to be able to next identfiy the store_id


 latest_date as (select s.staff_id, 
max(payment_date) as latest_payment_date
from staff s
left join payment p 
on s.staff_id =p.staff_id
where extract(year from p.payment_date ) = 2017
group by s.staff_id),

 store as(
select distinct s.staff_id, s.store_id
from staff s
left join latest_date d 
on s.staff_id =d.staff_id
left join payment p 
on s.staff_id =p.staff_id
where p.payment_date = d.latest_payment_date


)
--- added distinct here to avoid having duplicates

select 
s.name, 
s.revenue,
d.store_id

from top s
join store d
on s.staff_id=d.staff_id
order by s.revenue desc

--- I used join here because I only need info about the top three employees 
--- CTE for me has the most structured face among other solution


--1.2 solution version with subquery 

SELECT 
    sf.first_name, 
    sf.last_name, 
    st.store_id AS latest_store_id,  
    SUM(p.amount) AS revenue
FROM store st
JOIN staff sf ON st.store_id = sf.store_id
JOIN payment p ON sf.staff_id = p.staff_id
JOIN (                                                              
    SELECT staff_id, MAX(payment_date) AS latest_payment_date             --- Subquery to find the latest payment_date for each staff member
    FROM payment 
    WHERE payment_date BETWEEN '2017-01-01' AND '2017-12-31'              --- Filter for the year 2017
    GROUP BY staff_id  
) latest_payment ON p.staff_id = latest_payment.staff_id                  --- Join with the subquery to get the latest payment date
                 AND p.payment_date = latest_payment.latest_payment_date  --- Ensure matching the latest payment date
WHERE p.payment_date BETWEEN '2017-01-01' AND '2017-12-31' 
  AND sf.active = TRUE
GROUP BY st.store_id, sf.first_name, sf.last_name
ORDER BY revenue DESC
LIMIT 3;






--2. Show which 5 movies were rented more than others (number of rentals), 
--- what's the expected age of the audience for these movies? 

---- According to MPA rating system there are the following categories(G (up to the age of 10),PG(between 10 and 13, 
---- PG-13 (between 13 and 17), R(between 17 a, 18), NC-17(18+). So for them I take the medium age: G=5; PG=11.5; 
---- PG-13=15.5; R=17.5; NC-17 = 45 (The average life expectancy of a human is 72 so the median pint between 18 and 72 is 45)

---2.1 version 


SELECT 
    f.title, 
    COUNT(r.rental_id) AS number_of_rentals,
    CASE 
        WHEN f.rating = 'G' THEN 5                           --- Assign expected audience age based on rating
        WHEN f.rating = 'PG' THEN 11.5
        WHEN f.rating = 'PG-13' THEN 15.5
        WHEN f.rating = 'R' THEN 17.5
        WHEN f.rating = 'NC-17' THEN 45
    END AS expected_age_of_audience
FROM film f 
JOIN inventory i ON f.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
GROUP BY f.title, f.rating
ORDER BY number_of_rentals DESC
LIMIT 5;


--- 2.2  I use CTE here. I use CTE so in case I need to call certain attributes from there I can directly do so.
---- I do not specify the average ages for the MPA standards. Just use the  short definition of each age group instead

WITH movie_rentals AS (                  --- create a CTE called movie_rentals
    SELECT
        f.film_id,
        f.title,
        f.rating,
        COUNT(r.rental_id) AS rental_count,
        CASE
            WHEN f.rating = 'G' THEN 'All Ages'
            WHEN f.rating = 'PG' THEN 'Some material may not be suitable for children'
            WHEN f.rating = 'PG-13' THEN 'Parents strongly cautioned - Ages 13+'
            WHEN f.rating = 'R' THEN 'Under 17 requires adult - Ages 17+'
            WHEN f.rating = 'NC-17' THEN 'No one 17 and under - Adults Only'
            ELSE 'Rating not specified'
        END AS expected_age_audience
    FROM
        film f
    JOIN
        inventory i ON f.film_id = i.film_id
    JOIN
        rental r ON i.inventory_id = r.inventory_id              --- Execute the Inner Join in order to connect movie data to rental 
    GROUP BY
        f.film_id, f.title, f.rating
    ORDER BY                      
        rental_count DESC
    LIMIT 5
)
SELECT
    title,
    rental_count,
    rating,
    expected_age_audience
FROM
    movie_rentals;




---TASK3
--V1 latest release year and current year (diffference) for each actor

-- CTE

with latest_release as(
select 
a.first_name, 
a.last_name,
a.actor_id,
max(f.release_year) as latest_release_date

from actor a
left join film_actor fa 
on a.actor_id =fa.actor_id
left join film f
on f.film_id =fa.film_id
group by a.first_name, 
a.last_name,
a.actor_id)

select 
f.first_name,
f.last_name,
extract(year from current_date) - latest_release_date AS gap_days


from latest_release f
order by extract(year from current_date) - latest_release_date desc




-- subquery version

SELECT 
    t.first_name,
    t.last_name,
    EXTRACT(YEAR FROM CURRENT_DATE) - t.latest_release_date AS gap_days
FROM (
    SELECT 
        a.first_name, 
        a.last_name,
        a.actor_id,
        MAX(f.release_year) AS latest_release_date
    FROM actor a
    LEFT JOIN film_actor fa 
        ON a.actor_id = fa.actor_id
    LEFT JOIN film f
        ON f.film_id = fa.film_id
    GROUP BY 
        a.first_name, 
        a.last_name,
        a.actor_id
) t
ORDER BY gap_days DESC;


--- for this both versions are fine I dont differentiarte :d

----V2 gap between a sequential film for each actor


---   Find the year gap between each actor's latest and second-latest films
---   1. Identify each actor's most recent film year
---   2. Calculate the year difference between them

--- Get each actor's latest film year

-- CTE version

WITH actor_films AS (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        f.film_id,
        f.title,
        f.release_year
    FROM actor a
    JOIN film_actor fa 
        ON a.actor_id = fa.actor_id
    JOIN film f 
        ON fa.film_id = f.film_id
)

SELECT 
    af1.actor_id,
    af1.first_name,
    af1.last_name,
    af1.title AS current_film,
    af1.release_year AS current_year,
    
    MAX(af2.release_year) AS previous_year,
    
    af1.release_year - MAX(af2.release_year) AS gap_years

FROM actor_films af1

LEFT JOIN actor_films af2
    ON af1.actor_id = af2.actor_id
   AND af2.release_year <= af1.release_year and af2.film_id != af1.film_id  --- two movies mught have the same release year so the gap should be zero 

GROUP BY 
    af1.actor_id,
    af1.first_name,
    af1.last_name,
    af1.title,
    af1.release_year

HAVING MAX(af2.release_year) IS NOT NULL

ORDER BY 
    af1.actor_id,
    af1.release_year;



-- subquery version

--- this is super complicated and unstructured I would not have used this in the real project

SELECT 
    af1.actor_id,
    af1.first_name,
    af1.last_name,
    af1.title AS current_film,
    af1.release_year AS current_year,

    (
        SELECT MAX(f2.release_year)   --- I need to write and reqrite the subqueries cause I cant reference it  unlike the CTE
        FROM film_actor fa2
        JOIN film f2 
            ON fa2.film_id = f2.film_id
        WHERE fa2.actor_id = af1.actor_id
          AND (
                f2.release_year < af1.release_year
                OR (
                    f2.release_year = af1.release_year 
                    AND f2.film_id <> af1.film_id
                )
              )
    ) AS previous_year,

    af1.release_year - (
        SELECT MAX(f2.release_year)
        FROM film_actor fa2
        JOIN film f2 
            ON fa2.film_id = f2.film_id
        WHERE fa2.actor_id = af1.actor_id
          AND (
                f2.release_year < af1.release_year
                OR (
                    f2.release_year = af1.release_year 
                    AND f2.film_id <> af1.film_id
                )
              )
    ) AS gap_years

FROM (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        f.film_id,
        f.title,
        f.release_year
    FROM actor a
    JOIN film_actor fa 
        ON a.actor_id = fa.actor_id
    JOIN film f 
        ON fa.film_id = f.film_id
) af1

WHERE (
    SELECT MAX(f2.release_year)
    FROM film_actor fa2
    JOIN film f2 
        ON fa2.film_id = f2.film_id
    WHERE fa2.actor_id = af1.actor_id
      AND (
            f2.release_year < af1.release_year
            OR (
                f2.release_year = af1.release_year 
                AND f2.film_id <> af1.film_id
            )
          )
) IS NOT NULL

ORDER BY 
    af1.actor_id,
    af1.release_year;
















