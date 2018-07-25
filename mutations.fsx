#load "samples.fsx"

open FSharp.Data.AgensGraph
open Northwind

type MutationBuilder() =

    [<CustomOperation("updateVertex")>]
    member __.UpdateVertex(src, props, collection) =
        let src = graph { select src }
        Mutations.UpdateVertex(props, src, collection)

    member __.Zero() = Unchecked.defaultof<Mutation>

    member __.Yield(_) = Unchecked.defaultof<Mutation>

[<AutoOpen>]
module Computations =
    let mutation = MutationBuilder()

let test = mutation {
    updateVertex janet { janet.Properties with ReportsTo = None }
}