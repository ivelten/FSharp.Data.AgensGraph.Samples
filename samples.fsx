#load "northwind.fsx"

open FSharp.Data.AgensGraph
open Northwind

let customerOrders =
    graph {
        for (customer, purchased, order, orders, product) in Customer, Purchased, Order, Orders, Product do
        for p in (customer-|purchased|->(order-|orders|->product)) do
        select p
    }