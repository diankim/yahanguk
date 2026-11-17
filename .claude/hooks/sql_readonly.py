import json, re, sys

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

def readonly(q):
    s = strip(q).strip()
    s = re.sub(r";\s*$", "", s)
    if not s or ";" in s:
        return False
    if not re.match(r"^\(*\s*(select|with|show|table|values|explain)\b", s):
        return False
    if re.search(BAD_WORDS, s) or re.search(BAD_CALLS, s) or re.search(BAD_SCHEMAS, s):
        return False
    return True

try:
    d = json.load(sys.stdin)
    q = (d.get("tool_input") or {}).get("query") or ""
except Exception:
    sys.exit(0)
if readonly(q):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "읽기만 하는 SELECT"}}))
