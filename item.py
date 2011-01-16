# Restful article database
#
# End point url looks like http://myapp.com/<wiki>/article
#
# This resource supports the following collection REST actions:
#
# * PUT - create a new Wiki
# * * CGI-encoded content
# * * returns current store version (TBD)
# * GET - get articles from the wiki
# ** term=<search term> - return articles matching search term
# ** version=<version> - return articles modifed since version
# ** summary=true - return just a summary of what's in the store 
# * DELETE - delete the wiki
#
# In addition, it defines the following individual REST actions of the form <url>/name
#
# * PUT - create a new article
# * GET - get article from the wiki
# * DELETE - delete article

from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.ext import db
from django.utils import simplejson as json
import logging
import cgi

class Item(db.Model):
    name = db.StringProperty()
    content = db.StringProperty(multiline=True)
    update_date = db.DateTimeProperty()
    version = db.IntegerProperty()
    
    # return a hash for subsequent conversion to json
    def to_dict(self):
        return {
            "key": self.key().id_or_name(), 
            "store_name": self.parent_key().name(),
            "name": self.name, 
            "content": self.content,
            "version": self.version
        }
    def update_properties(self, name, content):
        if name:
            self.name = name
        if content:
            self.content = content
            
class Store(db.Model):
    version = db.IntegerProperty()
    
    def find_all(self):
        articles = Item.all()
        #return articles
        return articles.ancestor(self)

    def delete_all(self):
        count = 0
        for article in self.find_all():
            article.delete()
            count += 1
        return count
    
class LoggingHandler(webapp.RequestHandler):
    
    def log_header(self):
        return "STORE " + self.store_name()
        
    def log_method(self, method):
        logging.info("\n\n" + method + "  " + self.log_header() + " -- " + self.request.url)
        params = {}
        for name in self.request.arguments():
            params[name] = self.request.get(name)
        logging.info("  Params: " + json.dumps(params))
    
    def log_action(self, action):
        logging.info(self.log_header() + ":" + action)

    def store_name(self):
        return self.request.path.strip("/").partition("/")[0]

    def store_key(self):
        return db.Key.from_path("Store", self.store_name())
    
    def store(self):
        return db.get(self.store_key())
    
class ItemHandler(LoggingHandler):
    
    def get(self):
        self.log_method("GET")
        article = self.item()
        
        if article != None:
            self.log_action("Fetched")
            self.response.out.write(json.dumps(article.to_dict()))
        else:
            self.log_action("Failed to find")
            self.response.set_status(404)
            self.response.out.write('Item ' + self.item_name() + ' not found  ')
        
    def put(self):
        self.log_method("PUT")
        article = self.item()

        # due to bug in webapp, put doesn't get parameters from body
        params = cgi.parse_qs(self.request.body)
        store = db.get(self.store_key())
        new_article = article == None
        if new_article:
            article = Item(key_name=self.item_name(), parent=store.key())
        article.update_properties(params.get("name", [None])[0], params.get('content', [None])[0])
        store.version += 1
        article.version = store.version
        article.put()
        store.put()
        self.log_action("Created" if new_article else "Updated")
        self.response.set_status(201)
        self.response.out.write(str(article.version))

    def delete(self):
        self.log_method("DELETE")
        article = self.item()
        
        if article != None:
            article.delete()
            self.log_action("Deleted")
            self.response.out.write('deleted\n')
        else:
            self.log_action("Failed to delete")
            self.response.set_status(404)
            self.response.out.write('Not found')
    
    def log_header(self):
        return "STORE " + self.store_name() + " ITEM " + self.item_name()
        
        
    def item_name(self):
        return self.request.path.strip("/").split("/")[-1]

    def item(self):
        return db.get(self.item_key())
        
    def item_key(self):
        return db.Key.from_path("Item", self.item_name(), parent=self.store_key())

class StoreHandler(LoggingHandler):
      
    def log(self, action):
        logging.info(action + " store " + self.store_name())
        
    # Get articles and/or summary info from store
    def get(self):
        self.log_method('GET')
        store = self.store()
        if store == None:
            self.response.set_status(404)
            self.response.out.write('Store not found')
            return

        articles = store.find_all()
        if self.request.get("term"):
            search_name = self.request.get("term")
            self.log("fetching for " + search_name)
            articles = articles.filter("name >=", search_name).filter("name <", search_name + u"\ufffd")
        elif self.request.get('since_version'):
            articles = articles.filter("version >", int(self.request.get('since_version')))
        else:
            self.log("fetching all from")
        articles = articles.fetch(limit=1000)

        if self.request.get("summary", "false") == "true":
            result = { "version":  store.version }
        else:
            result = [article.to_dict() for article in articles]

        self.response.headers['Content-Type'] = 'application/json'
        self.response.out.write(json.dumps(result))

    def put(self):
        self.log_method("PUT")
        store = self.store()
        
        # due to bug in webapp, put doesn't get parameters from body
        params = cgi.parse_qs(self.request.body)
        is_new_store = store == None
        if is_new_store:
            store = Store(key_name=self.store_name())
            store.version = 0
        store.put()
        self.log("Created" if is_new_store else "Updated")
        self.response.set_status(201)
        self.response.out.write('Store ' + self.store_name() + ' created' + "\n")
        
    def delete(self):
        self.log_method('DELETE')
        store = self.store()
        if self.request.get("confirm", "false") != "true":
            self.log("Failed to delete - no confirmation")
            self.response.set_status(400)
            self.response.out.write('No confirmation for store delete')
            return
            
        if store == None:
            self.log("Failed to delete - store not found")
            self.response.set_status(404)
            self.response.out.write('Store not found')
            return
            
        count = store.delete_all()
        if self.request.get("keep_store", "false") == "true":
            store.version = 0
            store.put()
        else:
            store.delete()
        self.log("Deleted " + str(count) + ' articles')
        self.response.out.write('deleted\n')
        

application = webapp.WSGIApplication([
    ('/.*/article', StoreHandler),
    ('.*/article/.+', ItemHandler)
    ], debug=True)

def main():
    run_wsgi_app(application)

if __name__ == "__main__":
    main()