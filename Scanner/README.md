# SetaMac Scanner

This folder contains the production Python scanner bundled into SetaMac releases.

Generated local files are ignored:

- `library.json`
- `cache.json`
- `scan-progress.json`
- `scan.log`
- `.venv/`

SetaMac copies this folder into `SetaMac.app/Contents/Resources/Scanner` during release builds and excludes generated files, tests, and virtual environments from the app bundle.

For local scanner tests:

```bash
python3 -m venv Scanner/.venv
Scanner/.venv/bin/pip install -r Scanner/requirements.txt
Scanner/.venv/bin/python -m unittest discover -s Scanner/tests -v
```
