#r "packages/NETStandard.Library/build/netstandard2.0/ref/netstandard.dll"
#I "packages/System.Runtime.CompilerServices.Unsafe/lib/netstandard2.0/"
#I "packages/System.Threading.Tasks.Extensions/lib/netstandard2.0/"
#r "packages/Npgsql/lib/netstandard2.0/Npgsql.dll"
#r "packages/TaskBuilder.fs/lib/netstandard1.6/Taskbuilder.fs.dll"
#r "packages/FSharp.Data.AgensGraph/lib/netstandard2.0/FSharp.Data.AgensGraph.dll"
#r "System.Reflection.dll"

open FSharp.Data.AgensGraph

#if INTERACTIVE
let printer = TablePrinter.GetFsiPrinter(TablePrinterFormat.Alternative, enableCount = true, maxRows = 100)
fsi.AddPrintTransformer printer
#endif