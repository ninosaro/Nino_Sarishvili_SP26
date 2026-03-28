----- TASK1

--1. movies betweeb 2017 2019 rate >1 alphabetically sorted
select title from film a
where 1=1
and a.release_year  between 2017 and 2019
and a.rental_rate >1
order by title asc
-- For this task I would not have
-- used neither subquery not CTE



--2.revenue, group by rent 2017 march april address address2 aggregated in a  column
select distinct c.store_id, d.address || COALESCE(d.address2, '') as address, sum(b.amount)
from payment b
inner join customer c
on b.customer_id =c.customer_id 
inner join address d
on c.address_id=c.address_id
where 1=1
and b.payment_date >= '2017-03-01'  
and b.payment_date < '2017-04-30'
group by c.store_id,
d.address || COALESCE(d.address2, '')

-- I dont understand why I get different reults in this version and belpw in CTE versions

--2.1 CTE version
WITH address_a AS (
	SELECT s.store_id,
	a.address || COALESCE(a.address2, '') AS address_new   --- Combine address lines 1 and 2 into a single field
	FROM store s                                           --- COALESCE handles cases where address2 is NULL
	INNER JOIN address a ON a.address_id=s.address_id
	)                    

	
SELECT 
	address_new,
	s.store_id,
	SUM(p.amount) AS revenue 
FROM address_a aa                                          --- Called address from our CTE
JOIN store s ON aa.store_id = s.store_id
JOIN inventory i ON s.store_id = i.store_id
JOIN rental r ON i.inventory_id = r.inventory_id
JOIN payment p ON r.rental_id = p.rental_id
where p.payment_date >= '2017-03-01'  
and p.payment_date < '2017-04-30'
GROUP BY aa.address_new, s.store_id;


--3. fist_name, last_name, count number_of_movies, desc  limit 5


select e.first_name, e.last_name, count(distinct g.title)
from actor e
left join film_actor f
on e.actor_id=f.actor_id
left join film g
on f.film_id=g.film_id
where g.release_year >= 2015
group by e.first_name, e.last_name
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
from film h
left join film_category i
on h.film_id=i.film_id
left join category j
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

----V2 gap between a sequential film for each actor


---   Find the year gap between each actor's latest and second-latest films
---   1. Identify each actor's most recent film year
---   2. Calculate the year difference between them

--- Get each actor's latest film year



WITH actor_latest_movie AS (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        MAX(f.release_year) AS latest_year
    FROM actor a
    INNER JOIN film_actor fa ON a.actor_id = fa.actor_id 
    INNER JOIN film f ON fa.film_id = f.film_id           
    WHERE f.release_year IS NOT NULL                      --- Exclude NULL release years
    GROUP BY a.actor_id, a.first_name, a.last_name        
),
--- Get each actor's second-latest film year

actor_second_latest_movie AS (
    SELECT 
        a.actor_id,
        MAX(f.release_year) AS second_latest_year
    FROM actor a
    INNER JOIN film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN film f ON fa.film_id = f.film_id
    INNER JOIN actor_latest_movie alm ON a.actor_id = alm.actor_id
    WHERE f.release_year IS NOT NULL
      AND f.release_year < alm.latest_year  -- Must be older than the latest film
    GROUP BY a.actor_id
    HAVING MAX(f.release_year) IS NOT NULL  -- Ensure they have at least 2 films
)


--- Calculate gaps between the two most recent films
SELECT 
    alm.first_name,
    alm.last_name,
    (alm.latest_year - aslm.second_latest_year) AS year_gap
FROM actor_latest_movie alm
INNER JOIN actor_second_latest_movie aslm ON alm.actor_id = aslm.actor_id
ORDER BY year_gap DESC  -- Show largest gaps first
;  






















