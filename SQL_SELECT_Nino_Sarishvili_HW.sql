BEGIN;

-- 1. Choose your top-3 favorite movies and add them to the 'film' table
-- Using RETURNING to capture IDs for subsequent operations


WITH new_films AS (
  INSERT INTO film (title, description, release_year, language_id, rental_duration, 
                  rental_rate, length, replacement_cost, rating, special_features, last_update)
  SELECT 
    title, 
    description, 
    release_year, 
    language_id, 
    rental_duration, 
    rental_rate, 
    length, 
    replacement_cost, 
    rating::mpaa_rating, 
    string_to_array(special_features, ',')::text[],      --- convert comma-separated strings to arrays and explicitly casts the result to a text array type
    CURRENT_DATE
  FROM (VALUES
    ('Pride and Prejudice', 'Sparks fly when spirited Elizabeth Bennet meets single, rich, and proud Mr. Darcy.', 
     2005, 1, 3, 19.99, 127, 19.99, 'PG', 'Commentaries,Deleted Scenes'),
    ('Jane Eyre', 'A mousy governess who softens the heart of her employer soon discovers he is hiding a terrible secret.', 
     2011, 1, 2, 9.99, 120, 19.99, 'PG-13', 'Behind the Scenes'),
    ('Dancer in the Dark', 'An East European immigrant goes to America with her young son, expecting it to be like a Hollywood film.', 
     2000, 1, 1, 4.99, 140, 19.99, 'R', 'Trailers')
  ) AS f(title, description, release_year, language_id, rental_duration, rental_rate, 
         length, replacement_cost, rating, special_features)
  WHERE NOT EXISTS (SELECT 1 FROM film WHERE title = f.title)
  RETURNING film_id, title
)
SELECT * FROM new_films;

-- 2. Add actors with current_date last_update
WITH new_actors AS (
  INSERT INTO actor (first_name, last_name, last_update)
  SELECT first_name, last_name, CURRENT_DATE
  FROM (VALUES
    ('Keira', 'Knightley'),
    ('Matthew', 'Macfadyen'),
    ('Mia', 'Wasikowska'),
    ('Michael', 'Fassbender'),
    ('Björk', ''),
    ('Catherine', 'Deneuve')
  ) AS a(first_name, last_name)
  WHERE NOT EXISTS (
    SELECT 1 FROM actor 
    WHERE first_name = a.first_name AND last_name = a.last_name
  )
  RETURNING actor_id, first_name, last_name
)
SELECT * FROM new_actors;

-- 3. Link actors to films with proper array references
INSERT INTO film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE
FROM actor a
JOIN film f ON 
  (a.first_name = 'Keira' AND a.last_name = 'Knightley' AND f.title = 'Pride and Prejudice') OR
  (a.first_name = 'Matthew' AND a.last_name = 'Macfadyen' AND f.title = 'Pride and Prejudice') OR
  (a.first_name = 'Mia' AND a.last_name = 'Wasikowska' AND f.title = 'Jane Eyre') OR
  (a.first_name = 'Michael' AND a.last_name = 'Fassbender' AND f.title = 'Jane Eyre') OR
  (a.first_name = 'Björk' AND a.last_name = '' AND f.title = 'Dancer in the Dark') OR
  (a.first_name = 'Catherine' AND a.last_name = 'Deneuve' AND f.title = 'Dancer in the Dark')
WHERE NOT EXISTS (
  SELECT 1 FROM film_actor fa 
  WHERE fa.actor_id = a.actor_id AND fa.film_id = f.film_id
)
RETURNING actor_id, film_id;

-- 4. Add films to inventory with current_date last_update
INSERT INTO inventory (film_id, store_id, last_update)
SELECT f.film_id, 1, CURRENT_DATE
FROM film f
WHERE f.title IN ('Pride and Prejudice', 'Jane Eyre', 'Dancer in the Dark')
AND NOT EXISTS (
  SELECT 1 FROM inventory i 
  WHERE i.film_id = f.film_id AND i.store_id = 1
)
RETURNING inventory_id, film_id;

-- 5. Update customer record with verification
WITH eligible_customer AS (
  SELECT c.customer_id
  FROM customer c
  JOIN rental r ON c.customer_id = r.customer_id
  JOIN payment p ON c.customer_id = p.customer_id
  GROUP BY c.customer_id
  HAVING COUNT(DISTINCT r.rental_id) >= 43 AND COUNT(DISTINCT p.payment_id) >= 43
  LIMIT 1
)
UPDATE customer
SET 