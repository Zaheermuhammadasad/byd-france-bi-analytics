"""Download the original CCFA / PFA source files from the publishers' websites.

This repository does not redistribute the PDFs (CCFA reserves electronic
reproduction rights). This script fetches each file from the URL recorded in
docs/source_register.csv, saves it to data/raw/, and checks it against the
SHA-256 fingerprint in docs/raw_files.sha256, so you know you have exactly the
files the analysis was built on.

    python scripts/download_sources.py

Standard library only. Files already present with the right fingerprint are skipped.
If a publisher later replaces or moves a file, its fingerprint will no longer
match: the script reports it, and the analysis may then differ.
"""
import csv, hashlib, os, sys, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "data", "raw")
HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; byd-france-bi source downloader)"}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def main(register=os.path.join(ROOT, "docs", "source_register.csv"),
         fingerprints=os.path.join(ROOT, "docs", "raw_files.sha256")):
    expected = {}
    with open(fingerprints) as f:
        for line in f:
            if line.strip():
                digest, name = line.split(maxsplit=1)
                expected[name.strip()] = digest
    os.makedirs(RAW, exist_ok=True)
    ok = skipped = failed = 0
    with open(register, newline="", encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f) if (r.get("local_file") or "").startswith("data/raw/") and r.get("url")]
    for r in rows:
        name = os.path.basename(r["local_file"])
        dest = os.path.join(RAW, name)
        if os.path.exists(dest) and sha256(dest) == expected.get(name):
            skipped += 1
            continue
        try:
            req = urllib.request.Request(r["url"], headers=HEADERS)
            with urllib.request.urlopen(req, timeout=60) as resp, open(dest + ".part", "wb") as out:
                out.write(resp.read())
            os.replace(dest + ".part", dest)
        except Exception as e:                       # network error, 404, moved file...
            print(f"FAILED   {r['source_id']}  {name}: {e}")
            failed += 1
            continue
        if sha256(dest) == expected.get(name):
            print(f"OK       {r['source_id']}  {name}")
            ok += 1
        else:
            print(f"MISMATCH {r['source_id']}  {name}: downloaded, but the fingerprint differs from docs/raw_files.sha256")
            failed += 1
        time.sleep(1)                                # be polite to the publisher's server
    print(f"\n{ok} downloaded, {skipped} already present, {failed} failed or mismatched (of {len(rows)} files)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
