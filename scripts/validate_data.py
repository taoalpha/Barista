import json
import jsonschema
import os
import sys

def load_json(path):
    with open(path, 'r') as f:
        return json.load(f)

def validate_file(data_path, schema_path):
    try:
        data = load_json(data_path)
        schema = load_json(schema_path)
        jsonschema.validate(instance=data, schema=schema)
        print(f"✅ {os.path.basename(data_path)} is valid.")
        return True, data
    except jsonschema.exceptions.ValidationError as err:
        print(f"❌ {os.path.basename(data_path)} is invalid: {err.message}")
        return False, None
    except FileNotFoundError:
        print(f"❌ File not found: {data_path} or {schema_path}")
        return False, None
    except json.JSONDecodeError as err:
        print(f"❌ Error decoding JSON in {os.path.basename(data_path)}: {err.msg}")
        return False, None

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    data_dir = os.path.join(base_dir, 'data')
    schemas_dir = os.path.join(data_dir, 'schemas')
    
    # 1. Validate sources.json
    sources_file = os.path.join(data_dir, 'sources.json')
    sources_schema = os.path.join(schemas_dir, 'sources.schema.json')
    
    print("--- Validating Registry ---")
    valid_sources, sources_data = validate_file(sources_file, sources_schema)
    
    if not valid_sources:
        sys.exit(1)
        
    # 2. Validate each source file
    print("\n--- Validating Source Files ---")
    items_schema = os.path.join(schemas_dir, 'items.schema.json')
    
    all_valid = True
    for source in sources_data:
        filename = source.get('filename')
        if filename:
            file_path = os.path.join(data_dir, filename)
            valid, _ = validate_file(file_path, items_schema)
            if not valid:
                all_valid = False
                
    if all_valid:
        print("\n✨ All data files are valid!")
        sys.exit(0)
    else:
        print("\n⚠️ Some data files failed validation.")
        sys.exit(1)

if __name__ == "__main__":
    main()
