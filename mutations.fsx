#load "samples.fsx"

open FSharp.Data.AgensGraph
open Northwind
open Samples

type UpdatedVertexProperties<'U>(query : ISC<Vertex<'U>>, properties : 'U) =
    member __.Query = query
    member __.Properties = properties

type GraphBuilder with
    [<CustomOperation("updateVertex")>]
    member __.UpdateVertex(query : ISC<Vertex<'U>>, properties : Vertex<'U> -> 'U) =
        query

let props (e : Vertex<Employee>) = { e.Properties with ReportsTo = None }

let x = graph {
    for emp in Employee do
    updateVertex (emp.Properties)
}