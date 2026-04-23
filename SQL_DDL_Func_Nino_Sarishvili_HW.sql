--- 1. Create a view called 'sales_revenue_by_category_qtr' that shows the film category and total sales revenue for the current quarter and year. The view should only display categories with at least one sale in the current quarter. 
 --- Note: when the next quarter begins, it will be considered as the current quarter.



CREATE OR REPLACE VIEW public.sales_revenue_by_category_qtr AS      --- /create or replace view/ can refine the view and test changes by simply rerunning the script

WITH current_quarter AS (
    SELECT 
        EXTRACT(QUARTER FROM CURRENT_DATE) AS qtr, 
        EXTRACT(YEAR FROM CURRENT_DATE) AS yr,   
        DATE_TRUNC('quarter', CURRENT_DATE) AS quarter_start,
        (DATE_TRUNC('quarter', CURRENT_DATE) + INTERVAL '3 months') AS quarter_end
)   
SELECT 
    c.name AS category,
    SUM(p.amount) AS total_sales_revenue,
    (SELECT qtr FROM current_quarter) AS quarter, -- unnecessary query :d might have usedextracter yr and wtr in this very select :d if u dont insist I am a bit lazy to optimize this one
    (SELECT yr FROM current_quarter) AS year,
    (SELECT quarter_start FROM current_quarter) AS quarter_start_date,
    (SELECT quarter_end FROM current_quarter) AS quarter_end_date
FROM 
    public.payment p          
    JOIN public.rental r ON p.rental_id = r.rental_id
    JOIN public.inventory i ON r.inventory_id = i.inventory_id
    JOIN public.film f ON i.film_id = f.film_id
    JOIN public.film_category fc ON f.film_id = fc.film_id
    JOIN public.category c ON fc.category_id = c.category_id,
    current_quarter cq
WHERE 
    p.payment_date >= cq.quarter_start   -- I had some issue with this where - I used between before 
AND p.payment_date < cq.quarter_end      -- and it includes sometimes extra records (timestamp data) bcs of not considering the hrs difference (2026-04-01 00:00:00)

GROUP BY 
    c.name,
    (SELECT qtr FROM current_quarter),
    (SELECT yr FROM current_quarter), 
    (SELECT quarter_start FROM current_quarter),
    (SELECT quarter_end FROM current_quarter)
    
HAVING 
    SUM(p.amount) > 0   -- I have already used iiner join with the payment so the categories without sale should have been excluded naturally, but I guess this "having" doesnt hurt nobody? :ddd if it does pls tell me so <3
ORDER BY 
    total_sales_revenue DESC;

--- TEST, bcs no data was tretrieved from the previous query. It seems that the data is outdated, no data for 2025.
SELECT COUNT(*) 
FROM public.payment
WHERE payment_date >= DATE_TRUNC('quarter', CURRENT_DATE)
                       and payment_date < (DATE_TRUNC('quarter', CURRENT_DATE) + INTERVAL'3 months');





--- 2. Create a query language function called 'get_sales_revenue_by_category_qtr' that accepts one parameter representing the current quarter and year and returns the same result as the 'sales_revenue_by_category_qtr' view.

CREATE OR REPLACE FUNCTION public.get_sales_revenue_by_category_qtr(
    p_year INT,
    p_quarter INT
)
RETURNS TABLE (
    category TEXT,
    total_sales_revenue NUMERIC,
    quarter INT,
    year INT,
    quarter_start_date DATE,
    quarter_end_date DATE
)
LANGUAGE plpgsql   -- this tells that the function is swritten in pl/pgsql which supports if statements, loops ...
AS $$   
 
declare                      -- just like python I define my variables here so I know I will use them later
    v_quarter_start DATE;
    v_quarter_end DATE;
    v_count INT;
begin   --- starts executavle, everything after this runs step by step 
    /*
    Explanation:

    1. Why parameter is needed:
       The parameter allows querying revenue for ANY quarter and year,
       not only the current one. This makes the function reusable for 
       historical analysis and reporting. This is especially important 
       as the data that we are using is kind of outdated and doesnt contain 2026 at all.

    2. Invalid quarter handling:
       If quarter is not between 1 and 4, the function raises an exception.

    3. No data handling:
       If no sales exist for the given period, the function raises an exception
       to explicitly notify the user instead of returning empty results.
    */

    -- Validate quarter (this is called a defensive programming)
    IF p_quarter < 1 OR p_quarter > 4 THEN
        RAISE EXCEPTION 'Invalid quarter: %. Quarter must be between 1 and 4.', p_quarter;
    END IF;

    -- Calculate quarter start
    v_quarter_start := DATE_TRUNC('quarter', MAKE_DATE(p_year, (p_quarter - 1) * 3 + 1, 1)); -- builds a date in postgresql

    -- Calculate quarter end (start of next quarter)
    v_quarter_end := v_quarter_start + INTERVAL '3 months';

    -- Check if data exists
    SELECT COUNT(*) INTO v_count   --- this is like v_count := (result of COUNT(*)) store the result into a variable
    FROM payment
    WHERE payment_date >= v_quarter_start
      AND payment_date < v_quarter_end;

    IF v_count = 0 THEN
        RAISE EXCEPTION 'No data found for Year %, Quarter %', p_year, p_quarter;
    END IF;

    -- Return result
    RETURN QUERY   --- I use this when the function returns a table (multiple rows) otherwise could have used "returns int"
    SELECT 
        c.name,
        SUM(p.amount),
        p_quarter,
        p_year,
        v_quarter_start,
        v_quarter_end
    FROM public.payment p
    JOIN public.rental r ON p.rental_id = r.rental_id
    JOIN public.inventory i ON r.inventory_id = i.inventory_id
    JOIN public.film f ON i.film_id = f.film_id
    JOIN public.film_category fc ON f.film_id = fc.film_id
    JOIN public.category c ON fc.category_id = c.category_id
    WHERE 
        p.payment_date >= v_quarter_start
        AND p.payment_date < v_quarter_end
    GROUP BY 
        c.name
    ORDER BY 
        SUM(p.amount) DESC;

END;
$$;

-- test
SELECT * 
FROM get_sales_revenue_by_category_qtr(2005, 2); -- it will show the error bcs of non existent data

SELECT * 
FROM get_sales_revenue_by_category_qtr(2017, 2); -- this will return the output



---3. Create a function that takes a country as an input parameter and returns the most popular film in that specific country. 

CREATE OR REPLACE FUNCTION public.most_popular_films_by_countries(
    p_countries TEXT[] DEFAULT NULL  -- [] is an array lets me input several calues
)    -- default null lets me define raise exception below is no value was inserted
RETURNS TABLE (      -- should make sure that the result set has the exact same satatypes that I define here
    country TEXT,
    film TEXT,
    rating TEXT,
    language TEXT,
    length INT,
    release_year INT
)
LANGUAGE plpgsql
AS $$
BEGIN

    /*
    Explanation:

    1. Why parameter is needed:
       Allows flexible querying for any set of countries.

    2. Validation:
       Prevents NULL or empty input.

    3. Logic:
       - Count rentals per film per country
       - Rank films per country
       - Return top film with metadata
    */

    IF p_countries IS NULL OR array_length(p_countries, 1) IS NULL THEN
        RAISE EXCEPTION 'p_countries cannot be NULL or empty';
    END IF;

    RETURN QUERY

    WITH film_stats AS (
        SELECT
            co.country::TEXT                 AS fs_country,    -- I am type casting to match the datatype to my return table datatypes
            f.film_id,
            f.title::TEXT                    AS fs_film,
            f.rating::TEXT                   AS fs_rating,
            l.name::TEXT                    AS fs_language,
            f.length::INT                   AS fs_length,
            f.release_year::INT            AS fs_release_year,
            COUNT(r.rental_id)::INT        AS fs_total_rentals
        FROM public.country co
        JOIN public.city ci        ON ci.country_id = co.country_id
        JOIN public.address a      ON a.city_id = ci.city_id
        JOIN public.customer cu    ON cu.address_id = a.address_id
        JOIN public.rental r       ON r.customer_id = cu.customer_id
        JOIN public.inventory i    ON i.inventory_id = r.inventory_id
        JOIN public.film f         ON f.film_id = i.film_id
        JOIN public.language l     ON l.language_id = f.language_id
        WHERE co.country = ANY(p_countries)
        GROUP BY
            co.country,
            f.film_id,
            f.title,
            f.rating,
            l.name,
            f.length,
            f.release_year
    ),
    ranked AS (
        SELECT
            fs_country,
            fs_film,
            fs_rating,
            fs_language,
            fs_length,
            fs_release_year,
            ROW_NUMBER() OVER (
                PARTITION BY fs_country
                ORDER BY fs_total_rentals DESC, fs_film
            ) AS rn
        FROM film_stats
    )
    SELECT
        fs_country,
        fs_film,
        fs_rating,
        fs_language,
        fs_length,
        fs_release_year
    FROM ranked
    WHERE rn = 1;

END;
$$;
-- testing ^_^
SELECT *
FROM public.most_popular_films_by_countries(
    ARRAY['Afghanistan', 'Brazil', 'United States']
);

--- 4 
--Generates a list of films available in stock based on a partial title match.
--Returns film title, language, customer name, and rental date with a row number.
--If no films match the pattern, an exception is raised.

CREATE OR REPLACE FUNCTION public.films_in_stock_by_title(
    p_title TEXT DEFAULT NULL
)
RETURNS TABLE (
    row_num INT,
    film_title TEXT,
    language TEXT,
    customer_name TEXT,
    rental_date TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN

    /*
   
    PATTERN MATCHING (LIKE / ILIKE / %)
    - LIKE / ILIKE are used for pattern matching in SQL.
    - '%' means "any sequence of characters".
      Example: '%love%' matches "Love Story", "Crazy in Love", etc.
    - '_' means a single character.

   

    CASE SENSITIVITY
    - LIKE is case-sensitive
    - ILIKE is case-insensitive (used here)
    - So 'love', 'LOVE', 'LoVe' all return same results

    PERFORMANCE 
    Potential slow part:
    - WHERE f.title ILIKE '%' || p_title || '%' smart smart smart
      This prevents index usage (because of '%') → full table scan

    Optimization approach used:
    - Filtering is done as early as possible (in main SELECT)
    - Joins are applied only after filtering candidate films
    - LEFT JOIN used instead of heavy nested filtering logic
    - Avoided unnecessary CTEs that could materialize large datasets

    MULTIPLE MATCHES
    - If multiple films match pattern:
      → all are returned
      → ROW_NUMBER() generates sequential numbering

    NO MATCHES
    - If no film matches:
      → function returns an empty result set (no error)
      

    VALIDATION
    - NULL or empty input is not allowed
    - raises exception for invalid input ^^
    */

    IF p_title IS NULL OR p_title = '' THEN
        RAISE EXCEPTION 'Search pattern cannot be NULL or empty';
    END IF;

    RETURN QUERY

    SELECT
        ROW_NUMBER() OVER (ORDER BY f.title, r.rental_date)::INT AS row_num,
        f.title::TEXT AS film_title,
        l.name::TEXT AS language,
        CONCAT(cu.first_name, ' ', cu.last_name)::TEXT AS customer_name,
        r.rental_date::TIMESTAMP AS rental_date
    FROM public.film f
    JOIN public.language l ON l.language_id = f.language_id
    JOIN public.inventory i ON i.film_id = f.film_id
    LEFT JOIN public.rental r ON r.inventory_id = i.inventory_id
    LEFT JOIN public.customer cu ON cu.customer_id = r.customer_id
    WHERE f.title ILIKE '%' || p_title || '%';

END;
$$;
---check check check 

SELECT *
FROM public.films_in_stock_by_title('%love%');


--5. new_movie procedure language function
-- this should have p_title as a parameter and should insert a new movie into a film table
-- should set renta; rate to 4.99
-- replacement cost 19.99
-- duration 3 days
-- raise exception duplicate exists
--check language exists in the language table


CREATE OR REPLACE FUNCTION public.new_movie(
    p_title TEXT,
    p_release_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
    p_language TEXT DEFAULT 'English'
)
RETURNS VOID  -- this means that function does sth but doesnt return anything :d
LANGUAGE plpgsql -- plsql postgresql languages :d supports several things though
AS $$   -- opens the function logic
DECLARE    -- this are our variables I use to temporarly store some data 
    v_language_id INT;
    v_film_id INT;
BEGIN

    /*
   purpose
    Inserts a new movie into the film table with predefined business rules:
    - rental_rate = 4.99
    - rental_duration = 3 days
    - replacement_cost = 19.99
    - release_year = current year (default)
    - language = 'Klingon' (default)

    --unique IDs are generate
    - film_id is generated using MAX(film_id) + 1
    - ensures sequential uniqueness without hardcoding
    - avoids dependency on sequences (as per task constraint)

    duplicate prevention
    - Before insert, we check if a film with the same title exists
    - Uses ILIKE for case-insensitive match
    - If duplicate exists → raises exception and stops execution

labguage validation
    - Checks if language exists in public.language table
    - If not found → raises exception

    what of a mocie already exists
    - Function stops execution
    - Raises error: "Movie already exists"

    if insert fails
    - Transaction is automatically rolled back by PostgreSQL
    - No partial or corrupted data remains

    consistency guarantee
    - All validations happen BEFORE insert
    - Ensures atomicity (all-or-nothing behavior)
    */

    -- 1. Check duplicate movie
    IF EXISTS (   -- if opens the block
        SELECT 1
        FROM public.film
        WHERE title ILIKE p_title
    ) THEN
        RAISE EXCEPTION 'Movie "%" already exists', p_title;
    END IF;   -- end if closes the block

    -- 2. Validate language exists
    SELECT l.language_id
    INTO v_language_id   ---into takes the SELECT query rsult and stores it into a variable v_...
    FROM public.language l
    WHERE l.name = p_language;

    IF v_language_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist', p_language;
    END IF;

    -- 3. Generate new film_id (no hardcoding)
    SELECT COALESCE(MAX(film_id), 0) + 1
    INTO v_film_id
    FROM public.film;

    -- 4. Insert new movie
    INSERT INTO public.film (
        film_id,
        title,
        release_year,
        language_id,
        rental_duration,
        rental_rate,
        replacement_cost
    )
    VALUES (
        v_film_id,
        p_title,
        p_release_year,
        v_language_id,
        3,
        4.99,
        19.99
    );

END;
$$;

--check check check
SELECT public.new_movie('inception');

-- double check
SELECT * 
FROM public.film 
WHERE title iLIKE '%inception%';

