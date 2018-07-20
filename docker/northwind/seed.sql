CREATE EXTENSION IF NOT EXISTS file_fdw;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE SERVER northwind FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE categories (
CategoryID int,
CategoryName varchar(15),
Description text
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/categories.csv', delimiter ',', quote '"', null '');

CREATE FOREIGN TABLE customers (
CustomerID char(5),
CompanyName varchar(40),
ContactName varchar(30),
ContactTitle varchar(30),
Address varchar(60),
City varchar(15),
Region varchar(15),
PostalCode varchar(10),
Country varchar(15),
Phone varchar(24),
Fax varchar(24)
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/customers.csv', delimiter ',', quote '"', null '');

CREATE FOREIGN TABLE employees (
EmployeeID int,
LastName varchar(20),
FirstName varchar(10),
Title varchar(30),
TitleOfCourtesy varchar(25),
BirthDate date,
HireDate date,
Address varchar(60),
City varchar(15),
Region varchar(15),
PostalCode varchar(10),
Country varchar(15),
HomePhone varchar(24),
Extension varchar(4),
Notes text,
ReportTo int,
PhotoPath varchar(255)
) 
SERVER northwind 
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/employees.csv', delimiter ',', quote '"', null '');

CREATE FOREIGN TABLE employee_territories (
EmployeeID int,
TerritoryID varchar(20)
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/employee_territories.csv', delimiter ',', quote '"', null ''); 

CREATE FOREIGN TABLE orders_details (
orderID int,
ProductID int,
UnitPrice numeric(18,2),
Quantity smallint,
Discount real
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/orders_details.csv', delimiter ',', quote '"', null ''); 

CREATE FOREIGN TABLE orders (
orderID int,
CustomerID char(5),
EmployeeID int,
orderDate date,
RequiredDate date,
ShippedDate date,
ShipVia int,
Freight numeric(18,2),
ShipName varchar(40),
ShipAddress varchar(60),
ShipCity varchar(15),
ShipRegion varchar(15), 
ShipPostalCode varchar(10), 
ShipCountry varchar(15) 
) 
SERVER northwind 
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/orders.csv', delimiter ',', quote '"', null ''); 

CREATE FOREIGN TABLE products (
ProductID int, 
ProductName varchar(40),
SupplierID int, 
CategoryID int, 
QuantityPerUnit varchar(20),
UnitPrice numeric(18,2), 
UnitsInStock smallint, 
UnitsOnorder smallint, 
ReorderLevel smallint, 
Discontinued bit 
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/products.csv', delimiter ',', quote '"', null '');

CREATE FOREIGN TABLE regions (
RegionID int,
RegionDescription char(50)
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/regions.csv', delimiter ',', quote '"', null ''); 

CREATE FOREIGN TABLE shippers (
ShipperID int,
CompanyName varchar(40),
Phone varchar(24)
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/shippers.csv', delimiter ',', quote '"', null ''); 

CREATE FOREIGN TABLE suppliers (
SupplierID int,
CompanyName varchar(40),
ContactName varchar(30),
ContactTitle varchar(30),
Address varchar(60),
City varchar(15),
Region varchar(15),
PostalCode varchar(10),
Country varchar(15),
Phone varchar(24),
Fax varchar(24),
HomePage text
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/suppliers.csv', delimiter ',', quote '"', null '');

CREATE FOREIGN TABLE territories (
TerritoryID varchar(20),
TerritoryDescription char(50),
RegionID int
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

CREATE PROPERTY INDEX ON category(categoryid);
CREATE PROPERTY INDEX ON customer(customerid);
CREATE PROPERTY INDEX ON employee(employeeid);
CREATE PROPERTY INDEX ON "order"(orderid);
CREATE PROPERTY INDEX ON product(productid);
CREATE PROPERTY INDEX ON region(regionid);
CREATE PROPERTY INDEX ON shipper(shipperid);
CREATE PROPERTY INDEX ON supplier(supplierid);
CREATE PROPERTY INDEX ON territory(territoryid);

LOAD FROM orders_details AS source
MATCH (n:"order"),(m:product)
WHERE n.orderid=to_jsonb((source).orderid)
AND m.productid=to_jsonb((source).productid)
CREATE (n)-[r:ORDERS {unitprice:(source).unitprice,quantity:(source).quantity,discount:(source).discount}]->(m);

MATCH (n:employee),(m:employee)
WHERE m.employeeid=n.reportto
CREATE (n)-[r:REPORTS_TO]->(m);

MATCH (n:supplier),(m:product)
WHERE m.supplierid=n.supplierid
CREATE (n)-[r:SUPPLIES]->(m);

MATCH (n:product),(m:category)
WHERE n.categoryid=m.categoryid
CREATE (n)-[r:PART_OF]->(m);

MATCH (n:customer),(m:"order")
WHERE m.customerid=n.customerid
CREATE (n)-[r:PURCHASED]->(m);

MATCH (n:employee),(m:"order")
WHERE m.employeeid=n.employeeid
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