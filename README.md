# FSharp.Data.AgensGraph.Samples

## Issues and ideas

1. Queries running against AgensGraph seems to match propertiy names of vertex and edges in camel case. The query translator system seems to automatically lower the first letter, but the others remain as they are. For example,
if we have a table like this

```sql
CREATE FOREIGN TABLE regions (
regionId int,
regionDescription char(50)
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/regions.csv', delimiter ',', quote '"', null '');
```

and if we map an edge to it like this

```fsharp
type Region =
    { RegionId : int
      RegionDescription : string }

let Region =
    vertex {
        context Northwind
        named "region"
        typed vertexof<Region>
    }
```

altough queries will run and map correctly into the `Region` record, filtering it by any of its properties will fail. One known workaroud for this is to quote field names of the original table in camel case:

```sql
CREATE FOREIGN TABLE regions (
"regionId" int,
"regionDescription" char(50)
) 
SERVER northwind
OPTIONS (FORMAT 'csv', HEADER 'true', FILENAME '/resources/regions.csv', delimiter ',', quote '"', null ''); 
```

2. Event system is not being initialized by the Store. A boilerplate sql script to seed event tables is necessary to work with the component:

```sql
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
```

3. Unique ID generator extension is needed by the component, but not automatically provided on the database. Currently, a sql script is necessary to work with the component:

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

4. Some matching queries are giving an error with a `@` character near an identifier. This seems to be happening when using an object obtained from another query. For example:

```fsharp
let employee id =
    graph {
        for employee in Employee do
        where (employee.Properties.EmployeeId = id)
        select employee
        single
    }

let janet = employee 3

let updateEmployee (e : Employee) =
    let query = 
        graph {
            for employee in Employee do
            where (employee.Properties.EmployeeId = e.EmployeeId)
        }
    connection.Execute [ Mutations.UpdateVertex(e, query, Employee) ]

// Running this in FSI gives this error:
> updateEmployee ({ janet.Properties with ReportsTo = None });;
Executing Command :
SET enable_eager = true;
set graph_path=northwind_graph;
MATCH (a) WHERE id(a) = id((SELECT * FROM (MATCH ("employee__f8f9a6":"employee")
WHERE ("employee__f8f9a6".'employeeId' = @e_ed3c60d5.employeeId)
RETURN "employee__f8f9a6" as "employee__f8f9a6"

) AS q_0)) SET a = @p0;

[FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.String]]
Npgsql.PostgresException (0x80004005): 42601: syntax error at or near "@"...
```

A known workaround is to get the value directly instead of the original object. This works:

```fsharp
let updateEmployee (e : Employee) =
    let id = e.EmployeeId
    let query = 
        graph {
            for employee in Employee do
            where (employee.Properties.EmployeeId = id)
        }
    connection.Execute [ Mutations.UpdateVertex(e, query, Employee) ]

> updateEmployee ({ janet.Properties with ReportsTo = None });;
Executing Command :
SET enable_eager = true;
set graph_path=northwind_graph;
MATCH (a) WHERE id(a) = id((SELECT * FROM (MATCH ("employee__f8f9a6":"employee")
WHERE ("employee__f8f9a6".'employeeId' = @id_3)
RETURN "employee__f8f9a6" as "employee__f8f9a6"

) AS q_0)) SET a = @p0;

[FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.Int32]]
val it : unit = ()
```

5. UpsertVertex key mapping function needs to be passed as a lambda inside the function call. Any other way to do this (external function) will not work, even with `ReflectedDefinition` attribute. For example, this will not work:

```fsharp
let getKey (e : Employee) = e.EmployeeId

let removeManager (employee : Vertex<Employee>) =
    graph {
        for (reportsTo, manager) in ReportsTo, Employee do
        constrain (employee-|reportsTo|->manager)
        delete reportsTo
    } |> ignore
    let updated = { employee.Properties with ReportsTo = None }
    connection.Execute [ Mutations.UpsertVertex(getKey, updated, Employee) ]
```

But this will work:

```fsharp
let removeManager (employee : Vertex<Employee>) =
    graph {
        for (reportsTo, manager) in ReportsTo, Employee do
        constrain (employee-|reportsTo|->manager)
        delete reportsTo
    } |> ignore
    let updated = { employee.Properties with ReportsTo = None }
    connection.Execute [ Mutations.UpsertVertex((fun (e : Employee) -> e.EmployeeId), updated, Employee) ]
```