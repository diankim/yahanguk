def replace_pet(src, pid, new):
    s = src.index(f"pet(id='{pid}'")
    nxt = [i for i in (src.find('\npet(', s + 5), src.find('\n# ──', s + 5), src.find('\nBUT = ', s+5), src.find('\nBAEK = ', s+5), src.find('\nJANG = ', s+5), src.find('\nDRA = ', s+5), src.find('\nGIR =', s+5)) if i != -1]
    e = min(nxt) if nxt else len(src)
    return src[:s] + new.strip('\n') + '\n' + src[e:]
