#load "driver.fsx"

open System
open FSharp.Data.AgensGraph

type ReportsTo = ReportsTo
type Sold = Sold
type Purchased = Purchased
type Orders = Orders
type Rated = Rated
type Supplies = Supplies
type PartOf = PartOf

type Region =
    { RegionId : int
      RegionDescription : string }

type Shipper =
    { ShipperId : int
      Phone : string
      CompanyName : string }

type Territory =
    { TerritoryId : int
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
      ReportTo : int
      BirthDate : DateTime
      Address : string
      PostalCode : string
      HireDate : DateTime
      Country : string
      Region : string
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
      Fax : string
      CompanyName : string
      Country : string
      ContactTitle : string
      Phone : string
      ContactName : string
      Address : string
      PostalCode : string }

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
      Discontinued : bool }

type Category =
    { CategoryId : int
      CategoryName : string
      Description : string }

let store = Store.Open("User ID=postgres;Password=password;Host=localhost;Port=5432;Database=northwind;")
let connection = store.OpenConnection()

let Northwind = connection.GetGraphContext("northwind_graph")

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
        named "reports_to"
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

let Rated =
    edge {
        context Northwind
        named "rated"
        startVertex Customer
        endVertex Product
        typed edgeof<Rated>
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
        named "supplies"
        startVertex Supplier
        endVertex Product
        typed edgeof<Supplies>
    }