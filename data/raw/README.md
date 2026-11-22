# data/raw

**The source PDFs are not included in this repository.** CCFA reserves all reproduction rights to its publications, including electronic reproduction of downloadable documents.

Download them yourself from the publishers' websites:

```
python scripts/download_sources.py
```

The script reads each URL from `docs/source_register.csv` (34 CCFA monthly "Immatriculations VP" reports, January 2024 – October 2026, data AAA-DATA, plus one PFA flash report used as context only), saves the files here and checks each one against `docs/raw_files.sha256`. A matching fingerprint means you have exactly the files this analysis was built on.

These files are never edited: all processing writes to `data/processed/`.
