using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace ContosoUniversity.Entity
   {  
    public class En_Articles
        {
            public string id { get; set; }
            public string title { get; set; }
            public string author { get; set; }
            public DateTime date_submission { get; set; }
            public string reference_title { get; set; }
            public string reference_year { get; set; }
            public string reference_author { get; set; }
            public bool status { get; set; }
        }

    }