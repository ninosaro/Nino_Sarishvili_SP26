---- TASK 2
--1. create the table
CREATE TABLE public.table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::int) x;

-- execute time 15 seconds

--2 how much spaxe it takes up
SELECT *, pg_size_pretty(total_bytes) AS total,
                                    pg_size_pretty(index_bytes) AS INDEX,
                                    pg_size_pretty(toast_bytes) AS toast,
                                    pg_size_pretty(table_bytes) AS TABLE
               FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
                               FROM (SELECT c.oid,nspname AS table_schema,
                                                               relname AS TABLE_NAME,
                                                              c.reltuples AS row_estimate,
                                                              pg_total_relation_size(c.oid) AS total_bytes,
                                                              pg_indexes_size(c.oid) AS index_bytes,
                                                              pg_total_relation_size(reltoastrelid) AS toast_bytes
                                              FROM pg_class c
                                              LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
                                              WHERE relkind = 'r'
                                              ) a
                                    ) a
               WHERE table_name LIKE '%table_to_delete%';

--- total bytes equals to 602,521,600 
-- toast bytes 8192 
-- table bytes 602,513,408
-- total 575 MB

 ---3    delete operation 
 DELETE FROM table_to_deleteo
 WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0; -- removes 1/3 of all rows
-- execution time 21 seconds longer than creating a table (15 seconds)
 -- here I again check for the space and 
-- after delete it still takes up 575 MB


VACUUM FULL VERBOSE public.table_to_delete;
--public.table_to_delete": found 0 removable, 6666667 nonremovable row versions in 73530 pages
--after vacuuming space comes down to 383 MB  (removed or marked dead tuples)
DROP TABLE public.table_to_delete;
-- recreate (in order to recreate I need to drpt the table first)
CREATE TABLE public.table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1, 10000000) x;



--4. Truncate operations
TRUNCATE table_to_delete;
--Note how much time it takes to perform this TRUNCATE statement.
-- Compare with previous results and make conclusion.
-- Check space consumption of the table once again and make conclusions;
--execution time 1.379 s super fast (much faster then delete) updated rows zero
-- no space left 0 bytes s left it doesnt scan rows unlike delete and frees up the space efficiently


--5. 


--a. Space consumption before and after operation:

--After creating a table:
--table was around ~575 MB

--After DELETE:
--space was still almost the same (~575 MB) because deleted rows are still stored as dead tuples

--After VACUUM FULL:
--space dropped a lot (table got physically rewritten) disk space was actually freed

--After TRUNCATE:
--table size became almost 0 / very small all rows removed instantly


-- b.DELETE vs Truncate

--DELETE
--execution time: slow (depends on rows, in my case very slow cause 10M rows)
--disk space: NOT freed immediately
--transaction behavior: fully transactional
 --rollback: YES, can rollback before commit

 --TRUNCATE
--execution time: very fast (almost instant)
--disk space: freed immediately
--transaction behavior: also transactional (but works on whole table)
-- rollback: usually not

--c. Explanations

--why DELETE does not free space immediately
--DELETE only marks rows as deleted 
--The physical data is still inside table file, so space is not released.

--why VACUUM FULL changes table size
--VACUUM FULL rewrites whole table from scratch.
--It removes dead tuples completely and gives space back to OS, so table becomes smaller.

--why TRUNCATE behaves differently
--TRUNCATE does not delete row by row.
--It just removes whole data pages at once, so it is much faster and frees space immediately.

--how these affect performance and storage
--DELETE → slow, heavy, keeps storage, needs vacuum later
--VACUUM FULL → frees space but locks table, heavy operation
--TRUNCATE → fastest, best for clearing all data, minimal storage 


