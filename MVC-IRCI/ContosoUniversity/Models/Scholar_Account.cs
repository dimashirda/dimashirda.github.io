using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data.Entity;

namespace ContosoUniversity.Models
{
    public class Scholar_Account
    {
        public int id { get; set; }
        public string username { get; set; }
        public string password { get; set; }
    }

    public class Scholar_AccountDBContext : DbContext
    {
        public DbSet<Scholar_Account> Scholar_Accounts { get; set; }
    }


}