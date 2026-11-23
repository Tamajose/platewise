"""Exercise real local GoTrue guest upgrade with an isolated Postgres schema.

This runner makes test accounts on loopback only. The wrapper should provide a
disposable GoTrue + Postgres instance and remove it after the check.
"""
import json
import os
import secrets
import subprocess
from urllib.error import HTTPError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

url = os.environ.get("PLATEWISE_AUTH_URL", "http://127.0.0.1:18090")
parsed = urlparse(url)
assert parsed.scheme == "http" and parsed.hostname in ("127.0.0.1", "localhost")
container = os.environ.get("PLATEWISE_AUTH_PG_CONTAINER", "platewise-pg17")
database = os.environ.get("PLATEWISE_AUTH_PG_DATABASE", "platewise_auth_it")


def call(path, payload=None, token=None, method="POST"):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = Request(url + path, None if payload is None else json.dumps(payload).encode(), headers, method=method)
    try:
        with urlopen(req, timeout=10) as response:
            body = response.read()
            return response.status, json.loads(body) if body else {}
    except HTTPError as error:
        return error.code, json.loads(error.read())


def sql(statement):
    return subprocess.check_output(
        ["docker", "exec", container, "psql", "-U", "postgres", "-d", database, "-At", "-v", "ON_ERROR_STOP=1", "-c", statement],
        text=True,
    ).splitlines()[0]


suffix = secrets.token_hex(6)
password = secrets.token_urlsafe(24)
first_email, second_email = f"guest-{suffix}@example.org", f"owner-{suffix}@example.org"
status, other = call("/signup", {"email": second_email, "password": password})
assert status == 200 and other["user"]["email"] == second_email, (status, other.get("error_code"))
status, anonymous = call("/signup", {"data": {}})
assert status == 200 and anonymous["user"]["is_anonymous"], (status, anonymous.get("error_code"))
user_id, token = anonymous["user"]["id"], anonymous["access_token"]
assert len(user_id) == 36
sql(
    "select public.pw_profile_write('" + user_id + "',"
    """'{"height_cm":170,"weight_kg":70,"daily_calorie_target":2000,"water_goal_ml":2000,"preferred_units":"metric","timezone":"Asia/Dhaka","preferred_language":"en"}')"""
)
status, conflict = call("/user", {"email": second_email}, token=token, method="PUT")
assert status >= 400, (status, conflict.get("error_code"))
status, still_guest = call("/user", token=token, method="GET")
assert status == 200 and still_guest["id"] == user_id and still_guest["is_anonymous"]
status, user = call("/user", {"email": first_email}, token=token, method="PUT")
assert status == 200 and user["email_confirmed_at"], (status, user.get("error_code"))
status, updated = call("/user", {"password": password}, token=token, method="PUT")
assert status == 200 and updated["id"] == user_id, (status, updated.get("error_code"))
status, login = call("/token?grant_type=password", {"email": first_email, "password": password})
assert status == 200 and login["user"]["id"] == user_id and not login["user"]["is_anonymous"], (status, login.get("error_code"))
assert sql("select count(*) from public.profiles where user_id='" + user_id + "'") == "1"
status, _ = call("/logout?scope=local", token=login["access_token"])
assert status in (200, 204)
status, fresh = call("/signup", {"data": {}})
assert status == 200 and fresh["user"]["id"] != user_id
assert sql("select count(*) from public.profiles where user_id='" + fresh["user"]["id"] + "'") == "0"
print("Local GoTrue: existing-email conflict preserved the guest, upgrade retained the profile UUID, sign-out opened a fresh guest.")
