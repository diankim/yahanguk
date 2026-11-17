import json, os, re, sys

def strip(q):
    q = re.sub(r"--[^\n]*", " ", q)
    q = re.sub(r"/\*.*?\*/", " ", q, flags=re.S)
    q = re.sub(r"(\$[A-Za-z0-9_]*\$).*?\1", " ''", q, flags=re.S)
    q = re.sub(r"'(?:[^']|'')*'", "''", q)
    q = re.sub(r'"(?:[^"]|"")*"', "x", q)
    return q.lower()

BAD_WORDS = r"\b(insert|update|delete|merge|drop|alter|create|grant|revoke|truncate|do|call|execute|copy|vacuum|analyze|reindex|cluster|lock|refresh|comment|security|set|reset|begin|commit|rollback|savepoint|prepare|deallocate|listen|notify|unlisten|discard|import|into|load|checkpoint|nextval|setval)\b"
BAD_CALLS = r"(\bworld_\w*|\bfn_\w*|\bhandle_\w*|\bset_config|\bdblink\w*|\blo_\w*|\bpg_(terminate|cancel|reload|read|ls|stat_file|notify|switch|rotate|advisory|promote|create|drop|replication|logical|sleep|file)\w*|\bcurrval|\bhttp\w*)\s*\("
BAD_SCHEMAS = r"\b(net|cron|realtime|vault|supabase_functions|pgsodium|extensions|graphql|storage|auth)\s*\.\s*\w+\s*\("

def safe_fns():
    try:
        p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_readonly_fns.txt")
        return {l.strip() for l in open(p, encoding="utf-8") if l.strip()}
    except Exception:
        return set()

SAFE = safe_fns()

def mask_safe(s):
    s = re.sub(r"\b(?:public\s*\.\s*)?world_\w+_rules\s*\(\s*\)", "0", s)
    return re.sub(r"\b(?:public\s*\.\s*)?((?:world|fn)_\w+)\s*\(", lambda m: "safe_fn(" if m.group(1) in SAFE else m.group(0), s)

def one(s):
    s = s.strip()
    if not re.match(r"^\(*\s*(select|with|show|table|values|explain)\b", s):
        return False
    if re.search(BAD_WORDS, s) or re.search(BAD_CALLS, s) or re.search(BAD_SCHEMAS, s):
        return False
    return True

def readonly(q):
    parts = [p for p in mask_safe(strip(q)).split(";") if p.strip()]
    return bool(parts) and all(one(p) for p in parts)

try:
    d = json.load(sys.stdin)
    q = (d.get("tool_input") or {}).get("query") or ""
except Exception:
    sys.exit(0)
if readonly(q):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "읽기만 하는 SELECT"}}))
else:
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "ask", "permissionDecisionReason": "운영 DB를 바꿀 수 있는 조회"}}))
