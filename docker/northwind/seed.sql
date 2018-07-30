CREATE EXTENSION IF NOT EXISTS file_fdw;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE SERVER northwind FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE categories (
CategoryId int,
CategoryName varchar(15),
Description text
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/categories.csv', delimiter ',', quote '"', null '');

CREATE FOREIGN TABLE customers (
"customerId" char(5),
"companyName" varchar(40),
"contactName" varchar(30),
"contactTitle" varchar(30),
"address" varchar(60),
"city" varchar(15),
"region" varchar(15),
"postalCode" varchar(10),
"country" varchar(15),
"phone" varchar(24),
"fax" varchar(24)
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/customers.csv', delimiter ',', quote '"', null '');

CREATE FOREIGN TABLE employees (
"employeeId" int,
"lastName" varchar(20),
"firstName" varchar(10),
"title" varchar(30),
"titleOfCourtesy" varchar(25),
"birthDate" date,
"hireDate" date,
"address" varchar(60),
"city" varchar(15),
"region" varchar(15),
"postalCode" varchar(10),
"country" varchar(15),
"homePhone" varchar(24),
"extension" varchar(4),
"notes" text,
"reportsTo" int,
"photoPath" varchar(255)
) 
SERVER northwind 
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/employees.csv', delimiter ',', quote '"', null '');

CREATE FOREIGN TABLE employee_territories (
"employeeId" int,
"territoryId" varchar(20)
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/employee_territories.csv', delimiter ',', quote '"', null ''); 

CREATE FOREIGN TABLE orders_details (
"orderId" int,
"productId" int,
"unitPrice" numeric(18,2),
"quantity" smallint,
"discount" real
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/orders_details.csv', delimiter ',', quote '"', null ''); 

CREATE FOREIGN TABLE orders (
"orderId" int,
"customerId" char(5),
"employeeId" int,
"orderDate" date,
"requiredDate" date,
"shippedDate" date,
"shipVia" int,
"freight" numeric(18,2),
"shipName" varchar(40),
"shipAddress" varchar(60),
"shipCity" varchar(15),
"shipRegion" varchar(15), 
"shipPostalCode" varchar(10), 
"shipCountry" varchar(15) 
) 
SERVER northwind 
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/orders.csv', delimiter ',', quote '"', null ''); 

CREATE FOREIGN TABLE products (
"productId" int, 
"productName" varchar(40),
"supplierId" int, 
"categoryId" int, 
"quantityPerUnit" varchar(20),
"unitPrice" numeric(18,2), 
"unitsInStock" smallint, 
"unitsOnOrder" smallint, 
"reorderLevel" smallint, 
"discontinued" bit 
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/products.csv', delimiter ',', quote '"', null '');

CREATE FOREIGN TABLE regions (
"regionId" int,
"regionDescription" char(50)
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/regions.csv', delimiter ',', quote '"', null ''); 

CREATE FOREIGN TABLE shippers (
"shipperId" int,
"companyName" varchar(40),
"phone" varchar(24)
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/shippers.csv', delimiter ',', quote '"', null ''); 

CREATE FOREIGN TABLE suppliers (
"supplierId" int,
"companyName" varchar(40),
"contactName" varchar(30),
"contactTitle" varchar(30),
Address varchar(60),
"city" varchar(15),
"region" varchar(15),
"postalCode" varchar(10),
"country" varchar(15),
"phone" varchar(24),
"fax" varchar(24),
"homePage" text
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/suppliers.csv', delimiter ',', quote '"', null '');

CREATE FOREIGN TABLE territories (
"territoryId" varchar(20),
"territoryDescription" char(50),
"regionId" int
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/territories.csv', delimiter ',', quote '"', null '');

CREATE GRAPH northwind_graph;
SET graph_path = northwind_graph;

LOAD FROM categories AS source CREATE (n:category=to_jsonb(source));
LOAD FROM customers AS source CREATE (n:customer=to_jsonb(source));
LOAD FROM employees AS source CREATE (n:employee=to_jsonb(source));
create vlabel if not exists "order";
LOAD FROM orders AS source CREATE (n:"order"=to_jsonb(source));
LOAD FROM products AS source CREATE (n:product=to_jsonb(source));
LOAD FROM regions AS source CREATE (n:region=to_jsonb(source));
LOAD FROM shippers AS source CREATE (n:shipper=to_jsonb(source));
LOAD FROM suppliers AS source CREATE (n:supplier=to_jsonb(source));
LOAD FROM territories AS source CREATE (n:territory=to_jsonb(source));

CREATE PROPERTY INDEX ON category("categoryId");
CREATE PROPERTY INDEX ON customer("customerId");
CREATE PROPERTY INDEX ON employee("employeeId");
CREATE PROPERTY INDEX ON "order"("orderId");
CREATE PROPERTY INDEX ON product("productId");
CREATE PROPERTY INDEX ON region("regionId");
CREATE PROPERTY INDEX ON shipper("shipperId");
CREATE PROPERTY INDEX ON supplier("supplierId");
CREATE PROPERTY INDEX ON territory("territoryId");

LOAD FROM orders_details AS source
MATCH (n:"order"),(m:product)
WHERE n."orderId"=to_jsonb((source)."orderId")
AND m."productId"=to_jsonb((source)."productId")
CREATE (n)-[r:ORDERS {"unitPrice":(source)."unitPrice","quantity":(source)."quantity","discount":(source)."discount"}]->(m);

MATCH (n:employee),(m:employee)
WHERE m."employeeId"=n."reportsTo"
CREATE (n)-[r:REPORTSTO]->(m);

MATCH (n:supplier),(m:product)
WHERE m."supplierId"=n."supplierId"
CREATE (n)-[r:SUPPLIES]->(m);

MATCH (n:product),(m:category)
WHERE n."categoryId"=m."categoryId"
CREATE (n)-[r:PART_OF]->(m);

MATCH (n:customer),(m:"order")
WHERE m."customerId"=n."customerId"
CREATE (n)-[r:PURCHASED]->(m);

MATCH (n:employee),(m:"order")
WHERE m."employeeId"=n."employeeId"
CREATE (n)-[r:SOLD]->(m);

DROP elabel IF EXISTS rated;
CREATE elabel IF NOT EXISTS rated;

MATCH (c:customer)-[:PURCHASED]->(o:"order")-[:ORDERS]->(p:product)
WITH c, count(p) AS total
MATCH (c)-[:PURCHASED]->(o:"order")-[:ORDERS]->(p:product)
WITH c, total, p, count(o) AS orders
WITH c, total, p, orders, orders*1.0/total AS rating
MERGE (c)-[rated:RATED {"totalCount": to_jsonb(total), "orderCount": to_jsonb(orders), rating: rating}]->(p);

-- Stream -> Category
CREATE OR REPLACE FUNCTION category(
  _stream_name varchar
)
RETURNS varchar
AS $$
BEGIN
  return split_part(_stream_name, '-', 1);
END;
$$ LANGUAGE plpgsql
IMMUTABLE;

-- Messages table

-- ----------------------------
--  Table structure for events
-- ----------------------------
CREATE TABLE "public"."events" (
  "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
  "stream_name" varchar(255) NOT NULL COLLATE "default",
  "type" varchar(255) NOT NULL COLLATE "default",
  "position" bigint NOT NULL,
  "global_position" bigserial NOT NULL ,
  "data" jsonb,
  "metadata" jsonb,
  "time" TIMESTAMP WITHOUT TIME ZONE DEFAULT (now() AT TIME ZONE 'utc') NOT NULL
)
WITH (OIDS=FALSE);

-- ----------------------------
--  Primary key structure for table events
-- ----------------------------
ALTER TABLE "public"."events" ADD PRIMARY KEY ("global_position") NOT DEFERRABLE INITIALLY IMMEDIATE;


CREATE INDEX "events_category_global_position_idx" ON "public"."events" USING btree(category(stream_name) COLLATE "default" "pg_catalog"."text_ops" ASC NULLS LAST, "global_position" "pg_catalog"."int8_ops" ASC NULLS LAST);
CREATE INDEX  "events_id_idx" ON "public"."events" USING btree(id ASC NULLS LAST);
CREATE UNIQUE INDEX  "events_stream_name_position_uniq_idx" ON "public"."events" USING btree(stream_name COLLATE "default" "pg_catalog"."text_ops" ASC NULLS LAST, "position" "pg_catalog"."int8_ops" ASC NULLS LAST);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event') THEN
    CREATE TYPE event AS (
      id varchar,
      stream_name varchar,
      type varchar,
      position bigint,
      global_position bigint,
      data varchar,
      metadata varchar,
      time timestamp
    );
  END IF;
END$$;


-- ----------------------------
--  FUNCTIONS
-- ----------------------------

-- Get Category Messages
CREATE OR REPLACE FUNCTION get_category_events(
  _category_name varchar,
  _position bigint DEFAULT 0,
  _batch_size bigint DEFAULT 1000,
  _condition varchar DEFAULT NULL
)
RETURNS SETOF event
AS $$
DECLARE
  command text;
BEGIN
  command := '
    SELECT
      id::varchar,
      stream_name::varchar,
      type::varchar,
      position::bigint,
      global_position::bigint,
      data::varchar,
      metadata::varchar,
      time::timestamp
    FROM
      events
    WHERE
      category(stream_name) = $1 AND
      global_position >= $2';

  if _condition is not null then
    command := command || ' AND
      %s';
    command := format(command, _condition);
  end if;

  command := command || '
    ORDER BY
      global_position ASC
    LIMIT
      $3';

  -- RAISE NOTICE '%', command;

  RETURN QUERY EXECUTE command USING _category_name, _position, _batch_size;
END;
$$ LANGUAGE plpgsql
VOLATILE;



-- Get Last event
CREATE OR REPLACE FUNCTION get_last_event(
  _stream_name varchar
)
RETURNS SETOF event
AS $$
DECLARE
  command text;
BEGIN
  command := '
    SELECT
      id::varchar,
      stream_name::varchar,
      type::varchar,
      position::bigint,
      global_position::bigint,
      data::varchar,
      metadata::varchar,
      time::timestamp
    FROM
      events
    WHERE
      stream_name = $1
    ORDER BY
      position DESC
    LIMIT
      1';

  -- RAISE NOTICE '%', command;

  RETURN QUERY EXECUTE command USING _stream_name;
END;
$$ LANGUAGE plpgsql
VOLATILE;



-- Get Stream Messages
CREATE OR REPLACE FUNCTION get_stream_events(
  _stream_name varchar,
  _position bigint DEFAULT 0,
  _batch_size bigint DEFAULT 1000,
  _condition varchar DEFAULT NULL
)
RETURNS SETOF event
AS $$
DECLARE
  command text;
BEGIN
  command := '
    SELECT
      id::varchar,
      stream_name::varchar,
      type::varchar,
      position::bigint,
      global_position::bigint,
      data::varchar,
      metadata::varchar,
      time::timestamp
    FROM
      events
    WHERE
      stream_name = $1 AND
      position >= $2';

  if _condition is not null then
    command := command || ' AND
      %s';
    command := format(command, _condition);
  end if;

  command := command || '
    ORDER BY
      position ASC
    LIMIT
      $3';

  -- RAISE NOTICE '%', command;

  RETURN QUERY EXECUTE command USING _stream_name, _position, _batch_size;
END;
$$ LANGUAGE plpgsql
VOLATILE;



CREATE OR REPLACE FUNCTION get_events(
  _type varchar DEFAULT NULL,
  _condition varchar DEFAULT NULL
)
RETURNS SETOF event
AS $$
DECLARE
  command text;
BEGIN
  command := '
    SELECT
      id::varchar,
      stream_name::varchar,
      type::varchar,
      position::bigint,
      global_position::bigint,
      data::varchar,
      metadata::varchar,
      time::timestamp
    FROM
      events';

  if _type is not null or _condition is not null then
    command := command || ' Where ';
    if _type is not null then
        command := command || 'type = ''%s''';
        command := format(command, _type);
    end if;
    if _condition is not null then
      if _type is not null then
        command := command || ' AND ';
      end if;
      command := command || '%s';
      command := format(command, _condition);
    end if;  
  end if;

  command := command || '
    ORDER BY
      global_position ASC';
  -- RAISE NOTICE '%', command;

  RETURN QUERY EXECUTE command;
END;
$$ LANGUAGE plpgsql
VOLATILE;



-- Hash 64
CREATE OR REPLACE FUNCTION hash_64(
  _stream_name varchar
)
RETURNS bigint
AS $$
DECLARE
  hash bigint;
BEGIN
  select left('x' || md5(_stream_name), 16)::bit(64)::bigint into hash;
  return hash;
END;
$$ LANGUAGE plpgsql
IMMUTABLE;

CREATE OR REPLACE FUNCTION stream_version(
  _stream_name varchar
)
RETURNS bigint
AS $$
DECLARE
  stream_version bigint;
BEGIN
  select max(position) into stream_version from events where stream_name = _stream_name;

  return stream_version;
END;
$$ LANGUAGE plpgsql
VOLATILE;


CREATE OR REPLACE FUNCTION write_event(
  _id varchar,
  _stream_name varchar,
  _type varchar,
  _data jsonb,
  _metadata jsonb DEFAULT NULL,
  _expected_version bigint DEFAULT NULL
)
RETURNS bigint
AS $$
DECLARE
  event_id uuid;
  stream_version bigint;
  position bigint;
  stream_name_hash bigint;
BEGIN
  event_id = uuid(_id);

  stream_name_hash = hash_64(_stream_name); 
  PERFORM pg_advisory_xact_lock(stream_name_hash);

  stream_version := stream_version(_stream_name);

  if stream_version is null then
    stream_version := -1;
  end if;

  if _expected_version is not null then
    if _expected_version != stream_version then
      raise exception 'Wrong expected version: % (Stream: %, Stream Version: %)', _expected_version, _stream_name, stream_version using errcode = 'E0001';
    end if;
  end if;

  position := stream_version + 1;

  insert into "events"
    (
      "id",
      "stream_name",
      "position",
      "type",
      "data",
      "metadata"
    )
  values
    (
      event_id,
      _stream_name,
      position,
      _type,
      _data,
      _metadata
    )
  ;

  return position;
END;
$$ LANGUAGE plpgsql
VOLATILE;