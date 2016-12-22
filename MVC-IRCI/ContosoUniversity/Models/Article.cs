using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data.Entity;
using Npgsql;
using ContosoUniversity.Models;
using ContosoUniversity.Entity;

namespace ContosoUniversity.Models
{
    public class EntityArticles
    {
        public int id { get; set; }
        public string title { get; set; }
        public string[] author { get; set; }
        public DateTime date_submission { get; set; }
        public string reference_title { get; set; }
        public string reference_year { get; set; }
        public string reference_author { get; set; }
        public bool status { get; set; }
    }

    public class Article
    {
        private NpgsqlConnection db;
        private NpgsqlCommand cmd = new NpgsqlCommand();
        private List<EntityArticles> model = new List<EntityArticles>();
        public Article()
        {
            this.db = Connection.Instance().getConnection();
            try {
                this.db.Open();
            }
            catch(Exception e)
            {

            }
        }
        ~Article()
        {
            this.db.Close();
        }

        public List<EntityArticles> getArticles()
        {
            this.cmd.Connection = this.db;
            this.cmd.CommandText = "SELECT * FROM irci.article WHERE status = '0' LIMIT 10";
            try
            {
                var reader = cmd.ExecuteReader();
                
                while (reader.Read())
                {
                    this.model.Add(new EntityArticles()
                    {
                        id = (int) reader["id"],
                        title = reader["title"].ToString(),
                        author = ((System.Collections.IEnumerable)reader["author"]).Cast<object>().Select(x => x.ToString()).ToArray(),
                        date_submission = System.DateTime.Parse(reader["date_submission"].ToString()),
                        reference_title = reader["reference_title"].ToString(),
                        reference_author = reader["reference_author"].ToString(),
                        reference_year = reader["reference_year"].ToString()
                    });

                    var tmp = this.model.Last();
                    System.Diagnostics.Debug.WriteLine(tmp.title + " " + tmp.author[0] + " " + tmp.date_submission.ToString());
                }

                reader.Close();
                cmd.Cancel();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.Write(ex);
            }
            
            return this.model;

        }

        /**
         * Processes the data: create profile based on article,
         * change the status of the created. Uses the data in
         * this.model (so getArticle has to be done first)
         **/
        public void processMetadata ()
        {
            System.Diagnostics.Debug.WriteLine("masuk");
            this.cmd.Connection = this.db;
           
            foreach (var article in this.model)
            {
                foreach (var author in article.author)
                {
                    this.cmd.CommandText = "INSERT INTO irci.scholar_profile VALUES ((SELECT max(id) FROM irci.scholar_profile) + 1, '" +
                        author + "', 1)";
                    cmd.ExecuteNonQuery();
                }
                
                this.cmd.CommandText = "UPDATE irci.article SET status = 1 WHERE id = " + article.id;
                cmd.ExecuteNonQuery();
            }
        }
    }
}

