# FSharp.Data.AgensGraph.Samples

## Issues and ideas

### Property name casing

Queries running against AgensGraph seems to match propertiy names of vertex and edges in camel case. The query translator system seems to automatically lower the first letter, but the others remain as they are. For example,
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

### Database initialization boilerplate scripts

Event system is not being initialized by the Store. A boilerplate sql script to seed event tables is necessary to work with the component:

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

Also, an Unique ID generator extension is needed by the component, but not automatically provided on the database. Currently, a sql script is necessary to work with the component:

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

### Query error: parameter building

Some matching queries are giving an error with a `@` character near an identifier. This seems to be happening when using an object obtained from another query (maybe some internal routine that maps arguments isn't working in all expected cases). For example:

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

### Suport for Source<'T> directly from a graph select from a Vertex

`UpdateVertex` does have a peculiar case where we need to inform the updated properties of the vertex, a `Source<Vertex<'T>>` which is a query to obtain the original object, and a `TypedVertices` to refer to the
vertice definition in the connection. If we have a function to update an emplooye like this

```fsharp
let updateFirstName (e : Vertex<Employee>) (newName : string) =
    let query = graph { select e }
    let updated = { e.Properties with FirstName = newName }
    connection.Execute [ Mutations.UpdateVertex(updated, query, Employee) ]
```

this will result in an error:

```fsharp
> updateFirstName janet "Janett";;
FSharp.Data.AgensGraph.QueryTranslationException: Exceção do tipo 'FSharp.Data.AgensGraph.QueryTranslationException' foi acionada.
   em FSharp.Data.AgensGraph.QueryTransformer.GraphBuilder.RunAsQuery[T](GraphBuilder x, FSharpExpr expr, TransContext ctx)
   em FSI_0002.Samples.updateFirstName(Vertex`1 e, String newName) na D:\Projects\FSharp.Data.AgensGraph.Samples\samples.fsx:linha 151
   em <StartupCode$FSI_0004>.$FSI_0004.main@()
Stopped due to error
```

### UpsertVertex issues

`UpsertVertex` key mapping function needs to be passed as a lambda inside the function call. Any other way to do this (external function) will not work, even with `ReflectedDefinition` attribute. For example, this will not work:

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

### Type Mapping exceptions

Many exceptions originated from type mapping (map objects from database and versa) actually don't give much information on what point the mapping did fail. Say, if our region object has a property name wrongly mapped:

```fsharp
type Region =
    { RegionIdx : int // intentional wrong name
      RegionDescription : string }

let region =
    graph {
        for region in Region do
        first
    }

> region.Properties;;
FSharp.Data.AgensGraph.TypeConverterException: Exceção do tipo 'FSharp.Data.AgensGraph.TypeConverterException' foi acionada.
   em <StartupCode$FSharp-Data-AgensGraph>.$TypeConversion.mapping@1-5(TypeConverterConfiguration config, FSharpMap`2 recordFields, String[] names, PropertyInfo tupledArg0, TypeConverter tupledArg1)
   em FSharp.Data.AgensGraph.RecordConverter`1.getValues(TypeConverterConfiguration config, FSharpMap`2 recordFields)
   em FSharp.Data.AgensGraph.RecordConverter`1.Read(Object value, TypeConverterConfiguration config)
   em System.Lazy`1.CreateValue()
   em System.Lazy`1.LazyInitValue()
   em System.Lazy`1.get_Value()
   em FSharp.Data.AgensGraph.TypeHelpers.VertexImpl`1.FSharp-Data-AgensGraph-Entity`1-get_Properties()
   em <StartupCode$FSI_0004>.$FSI_0004.main@()
Stopped due to error
```

Type mapping exceptions also happen for optional fields (when they are not mapped as an Option), and when methods like `single` are called with no results - perhaps an exception saying "Sequence contains no elements" would be better?

### Decimal serialization

Decimal values that are integers are serialized as integers in the json properties. This is causing a `TypeConverterException` when deserializing them:

```fsharp
let NorthwindEvents = connection.GetEventContext("public")

type AccountEvent =
    | Debited of decimal
    | Credited of decimal

let Account =
    event {
        context NorthwindEvents
        named "account"
        typed eventof<AccountEvent>
    }

let defaultStream = "account"

let credit amount = Account.Append(defaultStream, Credited amount)

let debit amount = Account.Append(defaultStream, Debited amount)

let getStreamEvents () = 
    NorthwindEvents.Events.GetStreamEvents(defaultStream)
    |> Seq.cast<Event<AccountEvent>>
    |> Seq.map (fun d -> d.Data)

> credit 100M;
- ;;
Executing Command :
select "public".write_event(uuid_generate_v4()::varchar, @stream, @type, @data, @metadata, @version);
[FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.DBNull]]
val it : int64 = 0L

> debit 50M;;
Executing Command :
select "public".write_event(uuid_generate_v4()::varchar, @stream, @type, @data, @metadata, @version);
[FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.DBNull]]
val it : int64 = 1L

> credit 200M;;
Executing Command :
select "public".write_event(uuid_generate_v4()::varchar, @stream, @type, @data, @metadata, @version);
[FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.DBNull]]
val it : int64 = 2L

> getStreamEvents();;
Executing Command :
select "public".get_stream_events(@stream, @position, @size);
[FSharp.Data.AgensGraph.Parameter`1[System.String];
 FSharp.Data.AgensGraph.Parameter`1[System.Int64];
 FSharp.Data.AgensGraph.Parameter`1[System.Int64]]
val it : seq<Northwind.AccountEvent> =
  Error: Exceção do tipo 'FSharp.Data.AgensGraph.TypeConverterException' foi acionada.
```