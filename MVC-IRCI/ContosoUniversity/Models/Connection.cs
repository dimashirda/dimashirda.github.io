using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using Npgsql;

namespace ContosoUniversity.Models
{
    public class Connection
    {
        private static Connection connection;
        private NpgsqlConnection nc;

        private Connection()
        {
            nc = new NpgsqlConnection("Host=localhost;Username=postgres;Password=root;Database=IRCI");
        }

        public static Connection Instance()
        {

            if (connection == null)
                connection = new Connection();
            return connection;
        }

        public NpgsqlConnection getConnection()
        {
            return nc;
        }

    }
}