---------------------------------------
-- SQL to Delete a Data Cube Product
---------------------------------------

-- Run as:
--    psql --file delete_product.sql -h <hostname> <dbname>

--
-- COUNT NUMBER OF DATASETS OF EACH TYPE (including archived)
--
\set QUIET on
\set ECHO errors
\set ON_ERROR_STOP on
\timing off
\set QUIET off
\conninfo

\echo 'Number of Datasets of Each Type (including archived)'
select
  count(*),
  t.name
from dataset
  left join dataset_type t on dataset.dataset_type_ref = t.id
group by t.name
order by t.name;

-- \prompt "Are you sure you want to continue? Press Ctrl-C here to abort."

\prompt 'Which product should be deleted: ' product_name
\set quoted_product '\'' :product_name '\''

\echo
\echo 'NUMBER OF ' :quoted_product ' DATASETS TO BE DELETED'
select
  archived is NULL as is_archived,
  count(*)
from dataset
  left join dataset_type on dataset.dataset_type_ref = dataset_type.id
where dataset_type.name = :quoted_product
group by is_archived;

--
-- CHECK FOR LINEAGE RECORDS
--


BEGIN;
-- Are there any datasets that are descendents of this product?
-- If so, they will need to be removed first!
\echo 'Number of descendent datasets. Do not continue if any exist!'
select count(*)
from dataset_source
  left join dataset d on dataset_source.source_dataset_ref = d.id
where d.dataset_type_ref = (select id
                            from dataset_type
                            where dataset_type.name = :quoted_product);

\prompt 'Are there any descendent datasets? (If so, delete WILL fail, press Ctrl-C to abort).' ignored_check

-- Are there any lineage records which need deleting?
-- These are the lineage history of the product we're deleting.
\echo 'Number of parent records for ' :product_name '. These will be deleted.'
select count(*)
from dataset_source
  left join dataset d on dataset_source.dataset_ref = d.id
where d.dataset_type_ref = (select id
                            from dataset_type
                            where dataset_type.name = :quoted_product);
--
-- DELETE LINEAGE RECORDS
--
-- \set SINGLESTEP on
\echo 'DELETING LINEAGE RECORDS'
WITH datasets as (SELECT id
                  FROM dataset
                  where dataset.dataset_type_ref = (select id
                                                    FROM dataset_type
                                                    WHERE name = :quoted_product))
DELETE FROM dataset_source
USING datasets
where dataset_source.dataset_ref = datasets.id;

--
-- CHECK FOR LOCATION RECORDS
--
\echo 'NUMBER OF DATASET LOCATION RECORDS'
WITH datasets as (SELECT id
                  FROM dataset
                  where dataset.dataset_type_ref = (select id
                                                    FROM dataset_type
                                                    WHERE name = :quoted_product))
select count(*)
from dataset_location, datasets
where dataset_location.dataset_ref = datasets.id;

--
-- DELETE LOCATION RECORDS
--
\echo 'DELETING DATASET LOCATION RECORDS'
WITH datasets as (SELECT id
                  FROM dataset
                  where dataset.dataset_type_ref = (select id
                                                    FROM dataset_type
                                                    WHERE name = :quoted_product))
DELETE FROM dataset_location
USING datasets
where dataset_location.dataset_ref = datasets.id;

--
-- DELETE DATASET RECORDS
--
\echo 'DELETING DATASET RECORDS'
DELETE FROM dataset
where dataset.dataset_type_ref = (select id
                                  from dataset_type
                                  where dataset_type.name = :quoted_product);

--
-- FINALLY, DELETE THE PRODUCT
--
\echo 'DELETING DATASET RECORD for ' :quoted_product
DELETE FROM dataset_type
where dataset_type.name = :quoted_product;

COMMIT;