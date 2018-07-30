#load "driver.fsx"

open System
open FSharp.Data.AgensGraph

type ReportsTo = ReportsTo

type Sold = Sold

type Purchased = Purchased

type Orders = Orders

type Supplies = Supplies

type PartOf = PartOf

type Rated = 
    { TotalCount : int
      OrderCount : int
      Rating : float }

module Edges =
    let reportsTo = ReportsTo

    let sold = Sold

    let purchased = Purchased

    let orders = Orders

    let supplies = Supplies

    let partOf = PartOf

    let rated totalCount orderCount rating =
        { TotalCount = totalCount
          OrderCount = orderCount
          Rating = rating }

type Region =
    { RegionIdx : int
      RegionDescription : string }

type Shipper =
    { ShipperId : int
      Phone : string
      CompanyName : string }

type Territory =
    { TerritoryId : string
      RegionId : int
      TerritoryDescription : string }

type Employee =
    { EmployeeId : int
      City : string
      TitleOfCourtesy : string
      FirstName : string
      LastName : string
      Extension : string
      Title : string
      PhotoPath : string
      Notes : string
      ReportsTo : int option
      BirthDate : DateTime
      Address : string
      PostalCode : string
      HireDate : DateTime
      Country : string
      Region : string option
      HomePhone : string }

type Order =
    { OrderId : int
      ShipVia : int
      ShippedDate : DateTime
      ShipName : string
      EmployeeId : int
      ShipPostalCode : string
      ShipCity : string
      ShipAddress : string
      CustomerId : string
      Freight : decimal
      ShipCountry : string
      OrderDate : DateTime }

type Customer =
    { CustomerId : string
      City : string
      Fax : string option
      CompanyName : string
      Country : string
      ContactTitle : string
      Phone : string
      ContactName : string
      Address : string
      PostalCode : string option }

type Supplier =
    { SupplierId : int
      City : string
      ContactTitle : string
      CompanyName : string
      Country : string
      Phone : string
      ContactName : string
      Address : string
      PostalCode : string }

type Product =
    { ProductId : int
      CategoryId : int
      SupplierId : int
      QuantityPerUnit : string
      UnitsInStock : int
      ProductName : string
      ReorderLevel : int
      UnitsOnOrder : int
      UnitPrice : decimal
      Discontinued : string }

type Category =
    { CategoryId : int
      CategoryName : string
      Description : string }

let connectionString = "User ID=postgres;Password=password;Host=localhost;Port=5432;Database=northwind;"

let configuration =
    { StoreConfiguration.Default with
        Logger = 
            { new Logger with 
                member __.LogCommand (text, parameters) =
                    printfn "Executing Command :\n%s\n%A" text parameters
            }
    }

let store = Store.Open(connectionString, configuration)

let connection = store.OpenConnection()

let Northwind = connection.GetGraphContext("northwind_graph")

let NorthwindEvents = connection.GetEventContext("public")

let Region =
    vertex {
        context Northwind
        named "region"
        typed vertexof<Region>
    }

let Shipper =
    vertex {
        context Northwind
        named "shipper"
        typed vertexof<Shipper>
    }

let Territory = 
    vertex {
        context Northwind
        named "territory"
        typed vertexof<Territory>
    }

let Employee =
    vertex {
        context Northwind
        named "employee"
        typed vertexof<Employee>
    }

let Order =
    vertex {
        context Northwind
        named "order"
        typed vertexof<Order>
    }

let Customer =
    vertex {
        context Northwind
        named "customer"
        typed vertexof<Customer>
    }

let Supplier =
    vertex {
        context Northwind
        named "supplier"
        typed vertexof<Supplier>
    }

let Product =
    vertex {
        context Northwind
        named "product"
        typed vertexof<Product>
    }

let Category =
    vertex {
        context Northwind
        named "category"
        typed vertexof<Category>
    }

let ReportsTo =
    edge {
        context Northwind
        named "reportsTo"
        startVertex Employee
        endVertex Employee
        typed edgeof<ReportsTo>
    }

let Sold =
    edge {
        context Northwind
        named "sold"
        startVertex Employee
        endVertex Order
        typed edgeof<Sold>
    }

let Purchased =
    edge {
        context Northwind
        named "purchased"
        startVertex Customer
        endVertex Order
        typed edgeof<Purchased>
    }

let Orders =
    edge {
        context Northwind
        named "orders"
        startVertex Order
        endVertex Product
        typed edgeof<Orders>
    }

let PartOf =
    edge {
        context Northwind
        named "part_of"
        startVertex Product
        endVertex Category
        typed edgeof<PartOf>
    }

let Supplies =
    edge {
        context Northwind
        named "supplier"
        startVertex Supplier
        endVertex Product
        typed edgeof<Supplies>
    }

let Rated =
    edge {
        context Northwind
        named "rated"
        startVertex Customer
        endVertex Product
        typed edgeof<Rated>
    }

type AccountEvent =
    | Debited of decimal
    | Credited of decimal

let Account =
    event {
        context NorthwindEvents
        named "account"
        typed eventof<AccountEvent>
    }