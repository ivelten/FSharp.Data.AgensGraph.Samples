#load "samples.fsx"

open FSharp.Data.AgensGraph
open Northwind
open Samples

type GraphBuilder with
    [<CustomOperation("updateVertex", MaintainsVariableSpace=true, AllowIntoPattern=true)>]
    member __.UpdateVertex(query : ISC<'T>, properties : 'U, collection : TypedVertices<'T, 'U>) =
        Mutations.UpdateVertex(properties, query, collection)

let props (e : Vertex<Employee>) = { e.Properties with ReportsTo = None }

let x = graph {
    for e in Employee do
    updateVertex (props e) Employee
}