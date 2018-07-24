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

DROP elabel IF EXISTS rated;
CREATE elabel IF NOT EXISTS rated;

MATCH (c:customer)-[:PURCHASED]->(o:"order")-[:ORDERS]->(p:product)
WITH c, count(p) AS total
MATCH (c)-[:PURCHASED]->(o:"order")-[:ORDERS]->(p:product)
WITH c, total, p, count(o) AS orders
WITH c, total, p, orders, orders*1.0/total AS rating
MERGE (c)-[rated:RATED {"totalCount": to_jsonb(total), "orderCount": to_jsonb(orders), rating: rating}]->(p);