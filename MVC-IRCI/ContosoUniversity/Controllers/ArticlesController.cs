using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Entity;
using System.Linq;
using System.Net;
using System.Web;
using System.Web.Mvc;
using ContosoUniversity.Models;
using ContosoUniversity.Entity;

namespace ContosoUniversity.Controllers
{
    public class ArticlesController : Controller
    {
        Article article = new Article();

        // GET: Articles
        public ActionResult Index()
        {
            ViewBag.articles = article.getArticles();
            return View();
        }
         
        public ActionResult Process()
        {
            article.getArticles();
            article.processMetadata();
            return RedirectToAction("Index");
        }
    }
}
