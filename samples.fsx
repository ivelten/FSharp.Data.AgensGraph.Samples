#load "northwind.fsx"
open System.Drawing

open FSharp.Data.AgensGraph
open Northwind

let regions =
    graph {
        for region in Region do
        select region.Properties
    }

let shippers =
    graph {
        for shipper in Shipper do
        select shipper.Properties
    }

let territories =
    graph {
        for territory in Territory do
        select territory.Properties
    }

let employees =
    graph {
        for employee in Employee do
        select employee.Properties
    }

let orders =
    graph {
        for order in Order do
        select order.Properties
    }

let customers =
    graph {
        for customer in Customer do
        select customer.Properties
    }

let suppliers =
    graph {
        for supplier in Supplier do
        select supplier.Properties
    }

let products =
    graph {
        for product in Product do
        select product.Properties
    }

let categories =
    graph {
        for category in Category do
        select category.Properties
    }

let customerOrders =
    graph {
        for (customer, purchased, order, orders, product) in Customer, Purchased, Order, Orders, Product do
        constrain (customer-|purchased|->(order-|orders|->product)) 
        select (customer, purchased, order, orders, product)
    }

let anatr =
    graph {
        for customer in Customer do
        where (customer.Properties.CustomerId = "ANATR")
        select customer
    }

let orderRates (customer : Vertex<Customer>) =
    graph {
        for (rated, product) in Rated, Product do
        constrain (customer-|rated|->product)
        select (customer, rated, product)
    }