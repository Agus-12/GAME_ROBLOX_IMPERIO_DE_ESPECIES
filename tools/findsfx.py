import json,urllib.request,urllib.parse,sys,re,time
from concurrent.futures import ThreadPoolExecutor
def get(u):
    try:
        r=urllib.request.Request(u,headers={"User-Agent":"Mozilla/5.0"})
        return json.load(urllib.request.urlopen(r,timeout=25))
    except Exception: return None
def search(kw):
    ids=[]
    for st in ["&sortType=3",""]:
        d=get("https://apis.roblox.com/toolbox-service/v1/marketplace/3?keyword="+urllib.parse.quote(kw)+"&limit=30"+st)
        if d:
            for x in d.get("data",[]):
                if x["id"] not in ids: ids.append(x["id"])
    return ids
def details(i): return get(f"https://economy.roblox.com/v2/assets/{i}/details")
MAXD=float(sys.argv[1])
for kw in sys.argv[2:]:
    print("="*74); print("BUSCANDO:",kw); print("="*74)
    ids=search(kw)
    res=[]
    for i in ids:
        res.append(details(i)); time.sleep(0.12)
    n=0
    for d in res:
        if not d: continue
        cr=d.get("Creator",{}).get("Name","")
        pse = (cr=="ProSoundEffects")
        desc=(d.get("Description") or "").replace("\n"," ")
        m=re.search(r"Duration:\s*([\d.]+)",desc)
        dur=float(m.group(1)) if m else -1
        if pse and dur>MAXD: continue
        if not pse and cr!="Roblox": continue
        n+=1
        print(f"{d['AssetId']:>18} {dur:>5.1f}s [{cr[:4]}] {d.get('Name','')[:44]:<44} {desc[:58]}")
    if n==0: print("   (nada)")
