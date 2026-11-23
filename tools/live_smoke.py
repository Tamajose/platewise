"""Check the Supabase-backed v1 API on a disposable local development project."""
import concurrent.futures
import json
import os
import uuid
from urllib.error import HTTPError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

base = os.environ.get("PLATEWISE_BACKEND_URL", "http://127.0.0.1:54321")
parsed = urlparse(base)
assert parsed.scheme == "http" and parsed.hostname in ("127.0.0.1", "localhost")
key = os.environ["PLATEWISE_BACKEND_PUBLISHABLE_KEY"]
storage = os.environ.get("PLATEWISE_TEST_STORAGE") == "1"


def request(path, value=None, token=None, method="POST"):
    headers = {"apikey": key, "content-type": "application/json"}
    if token:
        headers["authorization"] = "Bearer " + token
    req = Request(base + path, json.dumps(value).encode() if value is not None else None, headers, method=method)
    try:
        with urlopen(req, timeout=25) as stream:
            raw = stream.read()
            return stream.status, json.loads(raw) if raw else {}
    except HTTPError as failure:
        return failure.code, json.loads(failure.read())


def action(name, data=None, token=None, expected=200):
    code, body = request("/functions/v1/platewise", {"version": 1, "action": name, "input": data or {}}, token)
    assert code == expected, (name, code, body.get("error"))
    assert body.get("version") == 1 and body.get("request_id"), name
    return body.get("data") if 200 <= code < 300 else body["error"]


assert action("dashboard", expected=401)["code"] == "SESSION_REQUIRED"
guests = tuple(request("/auth/v1/signup", {"data": {}}) for _ in range(2))
assert all(status == 200 for status, _ in guests)
a, b = (v["access_token"] for _, v in guests)
profile = {"height_cm": 170, "weight_kg": 69, "daily_calorie_target": 2100, "timezone": "Asia/Dhaka",
           "preferred_units": "metric", "preferred_language": "en", "water_goal_ml": 2000, "target_confirmed": True}
assert action("update_profile", {**profile, "daily_calorie_target": 1199}, a, 400)["code"] == "TARGET_RANGE"
assert action("update_profile", profile, a)["daily_calorie_target"] == 2100
assert action("dashboard", token=b)["profile"] is None
assert action("analyze_text", {"description": "rice and dal", "language": "en"}, a, 503)["code"] == "AI_UNAVAILABLE"

meal_id = str(uuid.uuid4())
meal = {"id": meal_id, "source": "manual", "confidence": "low", "assumptions": [],
        "items": [{"name": "Rice", "unit": "cup", "quantity": 1, "estimated_grams": 160, "calorie_low": 183,
                   "calorie_high": 220, "protein_g": None, "carbohydrate_g": None, "fat_g": None, "fiber_g": None,
                   "sodium_mg": None, "nutrient_source": "unavailable", "provenance": "manual"}]}
assert action("dashboard", token=a)["meals"] == []
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
    assert [v["representative_calories"] for v in executor.map(lambda _: action("confirm_meal", meal, a), range(2))] == [202, 202]
assert len(action("dashboard", token=a)["meals"]) == 1
assert request("/rest/v1/meals?select=id", token=b, method="GET") == (200, [])
assert action("meal_image_url", {"id": meal_id}, b, 404)["code"] == "NOT_FOUND"

options = [{"kind": "menu", "key": "a", "name": "Khichuri", "portion": "One bowl", "printed_kcal": 480, "language": "en"},
           {"kind": "menu", "key": "b", "name": "Biryani", "portion": None, "printed_kcal": 700, "language": "en"}]
ranked = action("compare", {"options": options, "budget": 600}, a)
assert [x["fit"] for x in ranked["results"]] == ["fits", "above"]
nearby = action("nearby", {"latitude": 23.4607, "longitude": 91.1809, "radius_km": 3, "budget": 650}, a)
assert nearby["dataset"] == "seeded" and len(nearby["options"]) >= 4
water = action("log_water", {"id": str(uuid.uuid4()), "amount_ml": 250}, a)
assert action("weekly", token=a)["days"][-1]["water"] == 250
assert action("weekly_summary", token=a)["state"] == "insufficient"
action("delete_water", {"id": water["id"]}, a)
assert action("weekly", token=a)["days"][-1]["water"] == 0
action("delete_meal", {"id": meal_id}, a)
assert not action("dashboard", token=a)["meals"]
if storage:
    assert action("delete_data", token=a)["account_deleted"] is False
    assert not action("dashboard", token=a)["profile"]
    assert request("/auth/v1/user", token=a, method="GET")[0] == 200
    assert action("delete_account", token=a)["account_deleted"] is True
    assert request("/auth/v1/user", token=a, method="GET")[0] >= 400
elif os.environ.get("PLATEWISE_TEST_STORAGE_FAILURE") == "1":
    assert action("delete_data", token=a, expected=503)["code"] == "STORAGE_PENDING"
    assert action("dashboard", token=a)["deletion_pending"]
    assert action("log_water", {"id": str(uuid.uuid4()), "amount_ml": 250}, a, 409)["code"] == "DELETION_PENDING"
print("Local authenticated Edge API: profile, isolation, idempotent confirm, ranking, seeded nearby, hydration, weekly and meal deletion passed.")
