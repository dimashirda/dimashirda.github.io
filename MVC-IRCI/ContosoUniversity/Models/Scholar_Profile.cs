using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data.Entity;
using Npgsql;

namespace ContosoUniversity.Models
{
    public class EntityScholarProfile
    {
        public int id { get; set; }
        public string name { get; set; }
        public int citation_num { get; set; }
    }

    public class ScholarProfile
    {
        private NpgsqlConnection db;
        private NpgsqlCommand cmd = new NpgsqlCommand();
        private List<EntityScholarProfile> model = new List<EntityScholarProfile>();
        public ScholarProfile()
        {
            this.db = Connection.Instance().getConnection();
            this.db.Open();
        }
        ~ScholarProfile()
        {
            this.db.Close();
        }

        public EntityScholarProfile getProfile (int id)
        {
            this.cmd.Connection = this.db;
            this.cmd.CommandText = "SELECT * FROM irci.scholar_profile WHERE id = " + id;

            var reader = cmd.ExecuteReader();
            EntityScholarProfile output = new EntityScholarProfile()
            {
                id = (int)reader["id"],
                name = reader["name"].ToString(),
                citation_num = (int)reader["citation_num"]
            };

            return output;
        }

        public List<EntityScholarProfile> searchProfiles(string key, int page = 1)
        {
            this.cmd.Connection = this.db;
            this.cmd.CommandText = "SELECT * FROM irci.scholar_profile WHERE name LIKE '%" + key + "%'" +
                " LIMIT 10 OFFSET " + (page - 1).ToString();

            try
            {
                var reader = cmd.ExecuteReader();

                while (reader.Read())
                {
                    this.model.Add(new EntityScholarProfile()
                    {
                        id = (int)reader["id"],
                        name = reader["name"].ToString(),
                        citation_num = (int)reader["citation_num"]
                    });

                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.Write(ex);
            }
            return this.model;

        }
        
        //  Merged will be deleted, Merger persists
        public void mergeProfile (int idMerger, int idMerged)
        {
            this.cmd.Connection = this.db;

            try
            {
                this.cmd.CommandText = "SELECT citation_num FROM irci.scholar_profile WHERE id = " + idMerged;
                var reader = cmd.ExecuteReader();

                reader.Read();
                int mergedCitation = (int)reader["citation_num"];

                this.cmd.CommandText = "SELECT citation_num FROM irci.scholar_profile where id = " + idMerger;
                reader = cmd.ExecuteReader();

                reader.Read();
                int mergerCitation = (int)reader["citation_num"];

                this.cmd.CommandText = "UPDATE irci.scholar_profile SET citation_num = " + mergedCitation + mergerCitation
                    + " WHERE id = " + idMerger;
                cmd.ExecuteReader();

                this.cmd.CommandText = "DELETE FROM irci.scholar_profile WHERE id = " + idMerged;
                cmd.ExecuteReader();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.Write(ex);
            }
        }
    }
}