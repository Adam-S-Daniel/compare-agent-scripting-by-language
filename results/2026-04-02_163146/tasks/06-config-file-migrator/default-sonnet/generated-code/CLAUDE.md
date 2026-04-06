# Config File Migrator

## Running Tests

```bash
python3 -m unittest test_config_migrator -v
```

Or using the run script:
```bash
python3 run_tests.py
```

## Running the CLI

```bash
python3 config_migrator.py fixtures/basic.ini
python3 config_migrator.py fixtures/full_app.ini --json-out output.json --yaml-out output.yaml
```
