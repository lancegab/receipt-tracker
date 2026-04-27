#!/usr/bin/env python3
"""Import March 2026 budget data from Excel into Stash Dash."""
import requests, json

API = "https://api.receipt.lagablab.com/api"

def api(method, path, token, data=None, params=None):
    headers = {"Authorization": f"Bearer {token}"}
    r = getattr(requests, method)(f"{API}{path}", json=data, params=params, headers=headers)
    resp = r.json()
    if not resp.get("success"):
        print(f"  ERR {method.upper()} {path}: {resp.get('error', resp)}")
        return None
    return resp.get("data")

# ─── 1. Login Lance ─────────────────────────────────────────────────
print("=== 1. Login Lance ===")
r = requests.post(f"{API}/auth/login", json={"email": "lg.labrague@gmail.com", "password": "123Tracker!@#"})
d = r.json()["data"]
LT = d["accessToken"]
print(f"  Lance: {d['user']['id'][:8]}..")

# ─── 2. Register/Login LJean ────────────────────────────────────────
print("\n=== 2. Register LJean ===")
r = requests.post(f"{API}/auth/register", json={
    "email": "ljeanbajao@gmail.com", "password": "123Tracker!@#", "displayName": "LJean"
})
resp = r.json()
if resp.get("success"):
    JT = resp["data"]["accessToken"]
    print(f"  Registered: {resp['data']['user']['id'][:8]}..")
else:
    r = requests.post(f"{API}/auth/login", json={"email": "ljeanbajao@gmail.com", "password": "123Tracker!@#"})
    JT = r.json()["data"]["accessToken"]
    print(f"  Logged in (already exists)")

# Set LJean currency to PHP
api("patch", "/auth/me", JT, data={"defaultCurrency": "PHP"})

# ─── 3. Group "L's" ─────────────────────────────────────────────────
print("\n=== 3. Setup group L's ===")
groups = api("get", "/budget-groups", LT) or []
group_id = None
for g in groups:
    if "L" in g.get("name", ""):
        group_id = g["id"]
        print(f"  Found: {g['name']}")
        break

if not group_id:
    g = api("post", "/budget-groups", LT, data={"name": "L's", "description": "Lance + LJean shared", "currency": "PHP"})
    group_id = g["id"]
    print(f"  Created L's")

# Invite + accept LJean
api("post", f"/budget-groups/{group_id}/invite", LT, data={"email": "ljeanbajao@gmail.com"})
invitations = api("get", "/budget-groups/invitations", JT) or []
for inv in invitations:
    if inv.get("groupId") == group_id and inv.get("status") == "pending":
        api("post", f"/budget-groups/invitations/{inv['id']}/accept", JT)
        print(f"  LJean joined group")
        break

# ─── 4. Accounts ────────────────────────────────────────────────────
print("\n=== 4. Accounts ===")

def ensure_accounts(token, accounts_spec, label):
    existing = api("get", "/accounts", token) or []
    acct_map = {a["name"]: a["id"] for a in existing}
    for spec in accounts_spec:
        name = spec["name"]
        if name not in acct_map:
            a = api("post", "/accounts", token, data=spec)
            if a:
                acct_map[name] = a["id"]
                print(f"  [{label}] Created: {name}")
        else:
            print(f"  [{label}] Exists: {name}")
    return acct_map

lance_accts = ensure_accounts(LT, [
    {"name": "Cash", "type": "cash", "currency": "PHP", "balance": 0},
    {"name": "Bank", "type": "bank", "currency": "PHP", "balance": 0},
    {"name": "Metrobank Visa", "type": "credit_card", "currency": "PHP", "balance": 0},
    {"name": "Unionbank Mastercard", "type": "credit_card", "currency": "PHP", "balance": 0},
    {"name": "M Free Mastercard", "type": "credit_card", "currency": "PHP", "balance": 0},
    {"name": "HSBC Visa", "type": "credit_card", "currency": "PHP", "balance": 0},
    {"name": "BDO Mastercard", "type": "credit_card", "currency": "PHP", "balance": 0},
    {"name": "Toyota Mastercard", "type": "credit_card", "currency": "PHP", "balance": 0},
], "Lance")

ljean_accts = ensure_accounts(JT, [
    {"name": "Cash", "type": "cash", "currency": "PHP", "balance": 0},
    {"name": "Bank", "type": "bank", "currency": "PHP", "balance": 0},
    {"name": "BPI Mastercard", "type": "credit_card", "currency": "PHP", "balance": 0},
], "LJean")

# ─── 5. Delete existing March 2026 budgets (fresh start) ────────────
print("\n=== 5. Clear existing March 2026 budgets ===")
for token, label in [(LT, "Lance"), (JT, "LJean")]:
    existing = api("get", "/budgets", token, params={"month": "2026-03"}) or []
    for b in existing:
        api("delete", f"/budgets/{b['id']}", token)
        print(f"  Deleted: {b['name']}")

# ─── 6. Create budgets ──────────────────────────────────────────────
print("\n=== 6. Create March 2026 budgets ===")

shared_b = api("post", "/budgets", LT, data={"name": "Shared", "month": "2026-03", "currency": "PHP", "groupId": group_id})
SHARED = shared_b["id"]
print(f"  Shared: {SHARED[:8]}..")

ljean_b = api("post", "/budgets", JT, data={"name": "LJean", "month": "2026-03", "currency": "PHP"})
LJEAN_B = ljean_b["id"]
print(f"  LJean: {LJEAN_B[:8]}..")

lance_b = api("post", "/budgets", LT, data={"name": "Lance", "month": "2026-03", "currency": "PHP"})
LANCE_B = lance_b["id"]
print(f"  Lance: {LANCE_B[:8]}..")

# ─── 7. Budget items + weekly adjustments ────────────────────────────
print("\n=== 7. Budget items ===")

def add_items(bid, token, items, label):
    for i, item in enumerate(items):
        payload = {"name": item[0], "budgetedAmount": item[1], "sortOrder": i}
        if item[2]:  # linkedAccountId
            payload["linkedAccountId"] = item[2]
        result = api("post", f"/budgets/{bid}/items", token, data=payload)
        if result:
            iid = result["id"]
            weekly = item[3] if len(item) > 3 else {}
            for wk, amt in weekly.items():
                api("patch", f"/budgets/{bid}/items/{iid}/weekly/{wk}", token,
                    data={"manualAdjustment": amt})
            w_str = ", ".join(f"W{k}:{v}" for k,v in weekly.items()) if weekly else ""
            print(f"  [{label}] {item[0]}: {item[1]} {w_str}")

# SHARED (rows 2-12)
add_items(SHARED, LT, [
    # (name, budgeted, linkedAccountId, {week: adjustment})
    ("Daily", 4000, None, {1: -3127.31, 2: -1100, 3: -2140.84}),
    ("Dates", 1500, None, {1: -500, 3: -1295}),
    ("Cat Litter", 700, None, {2: -665}),
    ("Vet Budget", 2000, None, {}),
    ("Bajao Stuff", 0, None, {}),
    ("Friends Stuff", 1000, None, {}),
    ("Bali Utilities", 2000, None, {}),
    ("Parking + Tolls", 500, None, {}),
    ("Cat Food", 3500, None, {3: -4939.74}),
    ("Bank Transfer", 100, None, {2: -26}),
    ("Dentist", 0, None, {3: -4335}),
], "Shared")

# LJEAN (rows 14-28)
add_items(LJEAN_B, JT, [
    ("Tuition (Lis2)", 5000, None, {}),
    ("Tuition (Kyle)", 13100, None, {1: -14000}),
    ("Tuition (Kirby)", 8000, None, {}),
    ("WiFi", 2505, None, {1: -2000}),
    ("Mama", 3000, None, {2: -2000}),
    ("Veco", 4500, None, {}),
    ("Papa Meds", 18000, None, {2: -2727.86, 3: -1000}),
    ("Bajao Residence", 3000, None, {3: -5013.11}),
    ("BDay Lislis - Grocery", 7000, None, {1: -7000}),
    ("BDay Lislis - Others", 1500, None, {1: -3000}),
    ("Research (Lis2)", 500, None, {}),
    ("Lab (Kyle)", 1000, None, {}),
    ("Siblings Needs", 3000, None, {1: -700, 2: -1300}),
    ("Personal", 200, None, {2: -1885}),
    ("BPI Mastercard", 39000, ljean_accts.get("BPI Mastercard"), {3: -38900}),
], "LJean")

# LANCE (rows 31-49)
add_items(LANCE_B, LT, [
    ("Pag Ibig", 20729.09, None, {2: -20729.09}),
    ("BALI PDC", 58333.33, None, {2: -58333.33}),
    ("SPaylater", 16401.4, None, {3: -16401.4}),
    ("CLI Equity", 4500, None, {3: -4500}),
    ("Apas House", 23000, None, {3: -23000}),
    ("Metrobank Visa", 12475.77, lance_accts.get("Metrobank Visa"), {}),
    ("Apas Utilities", 5000, None, {}),
    ("Unionbank Mastercard", 29314.1, lance_accts.get("Unionbank Mastercard"), {}),
    ("M Free Mastercard", 14161.87, lance_accts.get("M Free Mastercard"), {}),
    ("HSBC Visa", 22973.68, lance_accts.get("HSBC Visa"), {}),
    ("BDO Mastercard", 45110.89, lance_accts.get("BDO Mastercard"), {}),
    ("Toyota Mastercard", 2114.89, lance_accts.get("Toyota Mastercard"), {}),
    ("Pag Ibig Ext", 1000, None, {}),
    ("Gas", 2500, None, {2: -1122.57}),
    ("BALI Discretionary", 1000, None, {1: -1584, 3: -483}),
    ("Labrague Stuff", 1000, None, {}),
    ("Insurance", 25000, None, {}),
    ("Tuition", 0, None, {}),
    ("Load", 300, None, {1: -109}),
], "Lance")

# ─── 8. Transactions from notes ──────────────────────────────────────
print("\n=== 8. Transactions ===")

LC = lance_accts["Cash"]
LB = lance_accts["Bank"]
JC = ljean_accts["Cash"]

# Shared transactions (from Notes column, on Lance's cash account)
shared_txns = [
    # Daily W1 notes: -340 Senyang, -2787.31 Groceries
    {"amount": 340, "date": "2026-03-02", "description": "Senyang", "type": "expense", "accountId": LC},
    {"amount": 2787.31, "date": "2026-03-03", "description": "Groceries", "type": "expense", "accountId": LC},
    # Daily W2 notes: -180 streetfood, -320 Senyang, -600 Bugas + Veggies
    {"amount": 180, "date": "2026-03-09", "description": "Street food", "type": "expense", "accountId": LC},
    {"amount": 320, "date": "2026-03-10", "description": "Senyang", "type": "expense", "accountId": LC},
    {"amount": 600, "date": "2026-03-11", "description": "Bugas + Veggies", "type": "expense", "accountId": LC},
    # Daily W3: Bali Grocery
    {"amount": 2140.84, "date": "2026-03-17", "description": "Bali Grocery", "type": "expense", "accountId": LC},
    # Dates W1: -500 Buwa + ALT
    {"amount": 500, "date": "2026-03-01", "description": "Buwa + ALT", "type": "expense", "accountId": LC},
    # Dates W3: -950 SOMAC, -345 Jollibee
    {"amount": 950, "date": "2026-03-15", "description": "SOMAC", "type": "expense", "accountId": LC},
    {"amount": 345, "date": "2026-03-16", "description": "Jollibee", "type": "expense", "accountId": LC},
    # Cat Litter W2
    {"amount": 665, "date": "2026-03-10", "description": "Cat Litter", "type": "expense", "accountId": LC},
    # Cat Food W3
    {"amount": 4939.74, "date": "2026-03-18", "description": "Cat Food", "type": "expense", "accountId": LC},
    # Bank Transfer W2
    {"amount": 26, "date": "2026-03-09", "description": "Bank Transfer Fee", "type": "expense", "accountId": LC},
    # Dentist W3
    {"amount": 4335, "date": "2026-03-19", "description": "Dentist", "type": "expense", "accountId": LC},
    # BALI Discretionary: -1584 Bali Plates (W1), -483 Bali MF (W3)
    {"amount": 1584, "date": "2026-03-03", "description": "Bali Plates", "type": "expense", "accountId": LC},
    {"amount": 483, "date": "2026-03-17", "description": "Bali MF", "type": "expense", "accountId": LC},
]

ljean_txns = [
    {"amount": 14000, "date": "2026-03-03", "description": "Tuition - Kyle", "type": "expense", "accountId": JC},
    {"amount": 2000, "date": "2026-03-02", "description": "WiFi Payment", "type": "expense", "accountId": JC},
    {"amount": 2000, "date": "2026-03-09", "description": "Mama everyday stuff", "type": "expense", "accountId": JC},
    {"amount": 2727.86, "date": "2026-03-10", "description": "Papa Meds", "type": "expense", "accountId": JC},
    {"amount": 1000, "date": "2026-03-17", "description": "Papa Meds", "type": "expense", "accountId": JC},
    {"amount": 5013.11, "date": "2026-03-18", "description": "Bajao Residence", "type": "expense", "accountId": JC},
    {"amount": 7000, "date": "2026-03-01", "description": "BDay Lislis - Grocery", "type": "expense", "accountId": JC},
    {"amount": 3000, "date": "2026-03-01", "description": "BDay Lislis - Others", "type": "expense", "accountId": JC},
    {"amount": 700, "date": "2026-03-04", "description": "Shish (Siblings)", "type": "expense", "accountId": JC},
    {"amount": 1300, "date": "2026-03-11", "description": "Cash allowance @ Cybergate", "type": "expense", "accountId": JC},
    {"amount": 1885, "date": "2026-03-12", "description": "Chair", "type": "expense", "accountId": JC},
    {"amount": 38900, "date": "2026-03-17", "description": "BPI Mastercard Payment",
     "type": "expense", "accountId": ljean_accts["BPI Mastercard"]},
]

lance_txns = [
    {"amount": 20729.09, "date": "2026-03-09", "description": "Pag-IBIG", "type": "expense", "accountId": LB},
    {"amount": 58333.33, "date": "2026-03-09", "description": "BALI PDC", "type": "expense", "accountId": LB},
    {"amount": 16401.4, "date": "2026-03-16", "description": "SPaylater", "type": "expense", "accountId": LB},
    {"amount": 4500, "date": "2026-03-17", "description": "CLI Equity", "type": "expense", "accountId": LB},
    {"amount": 23000, "date": "2026-03-18", "description": "Apas House Rent", "type": "expense", "accountId": LB},
    {"amount": 1122.57, "date": "2026-03-10", "description": "Gas", "type": "expense", "accountId": LC},
    {"amount": 109, "date": "2026-03-02", "description": "Load", "type": "expense", "accountId": LC},
]

for label, token, txns in [("Shared", LT, shared_txns), ("LJean", JT, ljean_txns), ("Lance", LT, lance_txns)]:
    print(f"\n  {label}: {len(txns)} transactions")
    for t in txns:
        r = api("post", "/transactions", token, data=t)
        s = "+" if r else "!"
        print(f"    {s} {t['description']}: {t['amount']}")

print("\n=== DONE ===")
print(f"  Shared budget: {SHARED}")
print(f"  LJean budget:  {LJEAN_B}")
print(f"  Lance budget:  {LANCE_B}")
print(f"  Group L's:     {group_id}")
