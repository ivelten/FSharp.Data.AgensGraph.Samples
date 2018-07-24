#load "northwind.fsx"

open FSharp.Data.AgensGraph
open Northwind

// Getting properties of all entities
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

// Query up objects, including customers, orders, and products
let customerOrders =
    graph {
        for (customer, purchased, order, orders, product) in Customer, Purchased, Order, Orders, Product do
        constrain (customer-|purchased|->(order-|orders|->product)) 
        select (customer, purchased, order, orders, product)
    }

// Selects a customer by it's Id
let customer id =
    graph {
        for customer in Customer do
        where (customer.Properties.CustomerId = id)
        select customer
        single
    }

// A sample customer
let anton = customer "ANTON"

// Shortest path between customer and order
let purchaseInfo (customer : Vertex<Customer>) =
    graph {
        for (purchased, order) in Purchased, Order do
        select (shortestPathOrNone(customer-|purchased|->order))
    }

// Rated edge shows info on how often an item ordered by a customer has been purchased
let orderRates (customer : Vertex<Customer>) =
    graph {
        for (rated, product) in Rated, Product do
        constrain (customer-|rated|->product)
        select (customer, rated, product)
    }

// Selects an employee by it's Id
let employee id =
    graph {
        for employee in Employee do
        where (employee.Properties.EmployeeId = id)
        select employee
        single
    }

// Removes relationship of an employee with it's manager
let removeManager (employee : Vertex<Employee>) =
    graph {
        for (reportsTo, manager) in ReportsTo, Employee do
        constrain (employee-|reportsTo|->manager)
        delete reportsTo
    } |> ignore
    let updated = { employee.Properties with ReportsTo = None }
    let source = graph { select employee }
    connection.Execute [ Mutations.UpdateVertex(updated, source, Employee) ]

// Createst a new relationship of an employee with a manager
let assignManager (employee : Vertex<Employee>) (manager : Vertex<Employee>) =
    let updated = { employee.Properties with ReportsTo = Some manager.Properties.EmployeeId }
    let source = graph { select employee }
    connection.Execute 
        [ Mutations.CreateEdge(Edges.reportsTo, ReportsTo, employee.Id, manager.Id)
          Mutations.UpdateVertex(updated, source, Employee) ]

// Updates a manager of an employee
let changeManager employee newManager =
    removeManager employee
    assignManager employee newManager

// Checks an employee actual manager
let getManager employee =
    graph {
        for (reportsTo, manager) in ReportsTo, Employee do
        constrain (employee-|reportsTo|->manager)
        select manager
    }

// Sample employees
let janet = employee 3
let steven = employee 5