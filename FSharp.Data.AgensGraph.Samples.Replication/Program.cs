using Npgsql;
using NpgsqlTypes;
using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace FSharp.Data.AgensGraph.Samples.Replication
{
    class Program
    {
        const string ConnectionString = "User ID=postgres;Password=password;Host=localhost;Port=5432;Database=northwind";

        static string ReplicationConnectionString =>
            new NpgsqlConnectionStringBuilder(ConnectionString) { ReplicationMode = ReplicationMode.Logical }.ToString();

        const string SlotName = "agensgraph_test";

        const string PluginName = "test_decoding";

        static NpgsqlLsn CreateReplicationSlot()
        {
            Console.WriteLine("Starting logical replication slot {0} with plugin {1}...", SlotName, PluginName);

            using (var connection = new NpgsqlConnection(ReplicationConnectionString))
            {
                connection.Open();

                var command = connection.CreateCommand();

                command.CommandText = string.Format("CREATE_REPLICATION_SLOT {0} LOGICAL {1}", SlotName, PluginName);

                using (var reader = command.ExecuteReader())
                {
                    if (reader.Read())
                    {
                        var lsn = NpgsqlLsn.Parse(reader.GetString(1));

                        Console.WriteLine("Logical replication slot {0} successfully created.", SlotName);

                        return lsn;
                    }
                }

                throw new Exception("Create replication failed. Expected to have a start LSN, but reader had no results.");
            }
        }

        static void DropReplicationSlot()
        {
            Console.WriteLine("Dropping logical replication slot {0}.", SlotName);

            using (var connection = new NpgsqlConnection(ReplicationConnectionString))
            {
                connection.Open();

                var command = connection.CreateCommand();

                command.CommandText = string.Format("DROP_REPLICATION_SLOT {0}", SlotName);

                command.ExecuteNonQuery();
            }

            Console.WriteLine("Logical replication slot {0} dropped successfully.", SlotName);
        }

        static void StartReplication(NpgsqlLsn lsn, CancellationToken ct)
        {
            Task.Run(() =>
            {
                Console.WriteLine("Starting logical replication on slot {0} with plugin {1}.", SlotName, PluginName);
                Console.WriteLine("Press ENTER to finish replication.");

                using (var connection = new NpgsqlConnection(ReplicationConnectionString))
                {
                    connection.Open();

                    using (var stream = connection.BeginReplication(string.Format("START_REPLICATION SLOT {0} LOGICAL {1}", SlotName, lsn), lsn))
                    using (var reader = new StreamReader(stream))
                    {
                        const int flushTimeout = 1000;
                        var flushTime = 0;
                        var sw = Stopwatch.StartNew();

                        while (true)
                        {
                            var status = stream.FetchNext();

                            if (status == NpgsqlReplicationStreamFetchStatus.Data)
                                Console.WriteLine(reader.ReadToEnd());

                            if (sw.ElapsedMilliseconds > flushTime + flushTimeout)
                            {
                                stream.Flush();
                                flushTime += flushTimeout;
                            }

                            Thread.Sleep(50);

                            if (ct.IsCancellationRequested)
                            {
                                Console.WriteLine("Finishing replication slot {0}...", SlotName);
                                break;
                            }
                        }
                    }
                }

                Console.WriteLine("Replication slot {0} stopped.", SlotName);
            });
        }

        static bool ReplicationSlotExists()
        {
            using (var connection = new NpgsqlConnection(ConnectionString))
            {
                connection.Open();

                var cmd = connection.CreateCommand();
                cmd.CommandText = $"SELECT count(*) FROM pg_replication_slots WHERE slot_name = '{SlotName}'";

                var value = (long)cmd.ExecuteScalar();

                return value > 0;
            }
        }

        static void Main(string[] args)
        {
            if (ReplicationSlotExists())
                DropReplicationSlot();

            var lsn = CreateReplicationSlot();
            var ts = new CancellationTokenSource();

            StartReplication(lsn, ts.Token);

            var key = Console.ReadKey();

            if (key.Key == ConsoleKey.Enter)
                ts.Cancel();

            DropReplicationSlot();
        }
    }
}
