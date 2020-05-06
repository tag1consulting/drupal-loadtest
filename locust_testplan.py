from locust import TaskSet, task, between
from locust.contrib.fasthttp import FastHttpLocust
import random
import string
import re

def random_word():
    """Return 1 to 12 random characters, a-z inclusive."""
    length = random.randint(1, 12)
    return "".join( [random.choice(string.ascii_lowercase[:26]) for i in range(length)] )

def random_sentence():
    """Return 3 to 15 random words, capitalizing the first and ending
    with a period to mimic a sentence."""
    length = random.randint(3, 15)
    return (" ".join(random_word() for i in range(length)) + '.').capitalize()

def random_paragraph():
    """Return 3 to 15 random sentences, seperating with a space."""
    length = random.randint(3, 15)
    return (" ".join(random_sentence() for i in range(length)))

def is_static_file(file):
    if "/misc" in file:
        return True
    elif "/themes" in file:
        return True
    else:
        return False

def fetch_static_assets(session, response):
    """Determine if a URL in the web page is a static asset and should be
    downloaded."""
    resource_urls = set()

    for url in re.findall(r'''src=['"](.*?)['"]''', response.text, re.I):
        if is_static_file(url):
            resource_urls.add(url)

    for url in set(resource_urls):
        session.client.get(url, name="(Static File)")

class AnonBrowsingUser(TaskSet):
    @task(15)
    def frontpage(l):
        """View the front page."""
        response = l.client.get("/", name="(Anonymous) Front page")
        fetch_static_assets(l, response)

    @task(10)
    def nodepage(l):
        """preptest.sh creates nodes from 1 through 10,000: randomly
        view one of these nodes.
        """
        nid = random.randint(1, 10000)
        l.client.get("/node/%i" % nid, name="(Anonymous) /node/[nid]")

    @task(3)
    def profilepage(l):
        """preptest.sh creates users from 3 through 5,002: randomly
        view one of these user profiles.
        """
        uid = random.randint(3, 5002)
        l.client.get("/user/%i" % uid, name="(Anonymous) /user/[uid]")

class AuthBrowsingUser(TaskSet):
    def on_start(l):
        """Log into the website to simulate authenticated traffic."""
        response = l.client.get("/user", name="(Auth) Login")
        drupal_form_build_id = re.search(r'''name="form_build_id" value=['"](.*?)['"]''', response.text)
        """preptest.sh creates test users starting from uid3 with usernames
        like "userUID" and password "12345". Randomly log into one of these
        users."""
        username = "user" + str(random.randint(3, 1000))
        password = "12345"
        r = l.client.post(
            "/user",
            {"name":username, "pass":password, "form_id":"user_login", "op":"Log+in", "form_build_id":drupal_form_build_id.group(0)}, name="(Auth) Logging in: /user")
        if r.status_code != 200:
            response.failure("Failed to log in: " + str(response.status_code))

    @task(15)
    def frontpage(l):
        """View the front page."""
        response = l.client.get("/", name="(Auth) Front page")
        fetch_static_assets(l, response)

    @task(10)
    def nodepage(l):
        """preptest.sh creates nodes from 1 through 10,000: randomly
        view one of these nodes.
        """
        nid = random.randint(1, 10000)
        l.client.get("/node/%i" % nid, name="(Auth) /node/[nid]")

    @task(3)
    def profilepage(l):
        """preptest.sh creates users from 3 through 5,002: randomly
        view one of these user profiles.
        """
        uid = random.randint(3, 5002)
        l.client.get("/user/%i" % uid, name="(Auth) /user/[uid]")

    @task(3)
    def postcomments(l):
        """preptest.sh creates nodes from 1 through 10,000: randomly
        add a comment to one of them, if it is a node type that has
        comments enabled.
        """
        nid = random.randint(1, 10000)
        response = l.client.get("/comment/reply/%i" % nid, name="(Auth) Comment form")
        drupal_form_build_id = re.search(r'''name="form_build_id" value=['"](.*?)['"]''', response.text)
        drupal_form_token = re.search(r'''name="form_token" value=['"](.*?)['"]''', response.text)
        drupal_form_id = re.search(r'''name="form_id" value=['"](.*?)['"]''', response.text)
        subject = random_sentence()
        response = l.client.post("/comment/reply/%i" % nid, {
            "subject":subject,
            "comment_body[und][0][value]":random_paragraph(),
            "comment_body[und][0][format]":"filtered_html",
            "form_token":drupal_form_token.group(0),
            "form_id":drupal_form_id.group(0),
            "op":"Save",
            "form_build_id":drupal_form_build_id.group(0)}, name="(Auth) Posting comment", catch_response=True)
        if response.status_code != 200:
            response.failure("Failed to post comment: " + str(response.status_code))
        elif subject.encode() not in response.content:
            response.failure("Failed to post comment: comment not showing up")
        else:
            response.success()

class WebsiteAuthUser(FastHttpLocust):
    weight = 1
    task_set = AuthBrowsingUser
    wait_time = between(0, 0)

class WebsiteAnonUser(FastHttpLocust):
    weight = 4
    task_set = AnonBrowsingUser
    wait_time = between(0, 0)
