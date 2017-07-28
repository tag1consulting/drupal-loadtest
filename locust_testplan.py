from locust import HttpLocust, TaskSet, task, events
from bs4 import BeautifulSoup
import random

def is_static_file(file):
    if "/misc" in file:
        return True
    elif "/themes" in file:
        return True
    else:
        return False

def random_word():
    import string
    length = random.randint(1, 12)
    return "".join( [random.choice(string.letters[:26]) for i in xrange(length)] )

def random_sentence():
    length = random.randint(3, 15)
    return (" ".join(random_word() for i in xrange(length)) + '.').capitalize()

def random_paragraph():
    length = random.randint(3, 15)
    return (" ".join(random_sentence() for i in xrange(length)))

def fetch_static_assets(session, response):
    resource_urls = set()
    soup = BeautifulSoup(response.text, "html.parser")

    for res in soup.find_all(src=True):
        url = res['src']
        if is_static_file(url):
            resource_urls.add(url)
        else:
            print "Skipping: " + url

    for url in set(resource_urls):
        #Note: If you are going to tag different static file paths differently,
        #this is where I would normally do that.
        session.client.get(url, name="(Static File)")

class AnonBrowsingUser(TaskSet):
    @task(15)
    def frontpage(l):
        response = l.client.get("/", name="(Anonymous) Front page")
        fetch_static_assets(l, response)

    @task(10)
    def nodepage(l):
        nid = random.randint(1, 10000)
        l.client.get("/node/%i" % nid, name="(Anonymous) /node/[nid]")

    @task(3)
    def profilepage(l):
        uid = random.randint(3, 5000)
        l.client.get("/user/%i" % uid, name="(Anonymous) /user/[uid]")

class AuthBrowsingUser(TaskSet):
    def on_start(l):
        response = l.client.get("/user", name="(Auth) Login")
        soup = BeautifulSoup(response.text, "html.parser")
        drupal_form_id = soup.select('input[name="form_build_id"]')[0]["value"]
        r = l.client.post("/user", {"name":"jeremy", "pass":"12345", "form_id":"user_login", "op":"Log+in", "form_build_id":drupal_form_id}, name="(Auth) Logging in: /user")

    @task(15)
    def frontpage(l):
        response = l.client.get("/", name="(Auth) Front page")
        fetch_static_assets(l, response)

    @task(10)
    def nodepage(l):
        nid = random.randint(1, 10000)
        l.client.get("/node/%i" % nid, name="(Auth) /node/[nid]")

    @task(3)
    def profilepage(l):
        uid = random.randint(1, 5000)
        l.client.get("/user/%i" % uid, name="(Auth) /user/[uid]")

    @task(3)
    def postcomments(l):
        nid = random.randint(1, 10000)
        response = l.client.get("/comment/reply/%i" % nid, name="(Auth) Comment form")
        soup = BeautifulSoup(response.text, "html.parser")
        drupal_form_build_id_object = soup.select('input[name="form_build_id"]')
        drupal_form_token_object = soup.select('input[name="form_token"]')
        if drupal_form_build_id_object and drupal_form_token_object:
            drupal_form_build_id = drupal_form_build_id_object[0]["value"]
            drupal_form_token = drupal_form_token_object[0]["value"]
            subject = random_sentence()
            response = l.client.post("/comment/reply/%i" % nid, {"subject":subject, "comment":random_paragraph(), "form_id":"comment_form", "form_token":drupal_form_token, "op":"Save", "form_build_id":drupal_form_build_id}, name="(Auth) Posting comment", catch_response=True)
            if response.status_code != 200:
                response.failure("Failed to post comment: " + str(response.status_code))
            elif subject not in response.content:
                response.failure("Failed to post comment: comment not showing up")
            else:
                response.success()

class WebsiteAuthUser(HttpLocust):
    weight = 1
    task_set = AuthBrowsingUser    

class WebsiteAnonUser(HttpLocust):
    weight = 4
    task_set = AnonBrowsingUser
