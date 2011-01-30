# UserHander
#
# Handles REST requests concerning the user
#
# This resource supports the following collection REST actions:
#
# * GET - gets information about the current user
#

from google.appengine.api import users
from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.ext import db
from django.utils import simplejson as json
import logging
import cgi

class UserHandler(webapp.RequestHandler):
    def get(self):
        user = users.get_current_user()
        self.response.headers['Content-Type'] = 'application/json'
        self.response.out.write(json.dumps({ 'email': user.email()}))

application = webapp.WSGIApplication([
    ('.*', UserHandler),
    ], debug=True)

def main():
    run_wsgi_app(application)

if __name__ == "__main__":
    main()