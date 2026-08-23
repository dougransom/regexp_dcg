#!/usr/bin/env python3
import sys
import re

def parse_exports(filepath):
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading file {filepath}: {e}", file=sys.stderr)
        return None, []
    
    # Remove block comments /* ... */
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    # Remove line comments % ...
    content = re.sub(r'%.*?\n', '\n', content)
    
    # Find module directive: :- module(name, [exports])
    match = re.search(r':-\s*module\s*\(\s*([a-zA-Z0-9_]+)\s*,\s*\[(.*?)\]\s*\)', content, re.DOTALL)
    if not match:
        print(f"Could not find module declaration in {filepath}", file=sys.stderr)
        return None, []
    
    module_name = match.group(1)
    exports_block = match.group(2)
    
    # Split by comma and clean
    exports = []
    for item in exports_block.split(','):
        item = item.strip()
        if not item:
            continue
        # item is like re_match/3 or re_match_dcg//2
        exports.append(item)
        
    return module_name, exports

def make_template(export):
    if '//' in export:
        # DCG non-terminal, e.g. re_match_dcg//2
        parts = export.split('//')
        name = parts[0].strip()
        arity = int(parts[1].strip())
        args = ", ".join(f"Arg{i+1}" for i in range(arity))
        sig = f"{name}({args})//" if arity > 0 else f"{name}//"
    elif '/' in export:
        # Standard predicate, e.g. re_match/3
        parts = export.split('/')
        name = parts[0].strip()
        arity = int(parts[1].strip())
        args = ", ".join(f"Arg{i+1}" for i in range(arity))
        sig = f"{name}({args})" if arity > 0 else name
    else:
        sig = export
        
    return f"%% {sig}\n%\n% TODO: Document {export}\n"

def main():
    if len(sys.argv) < 2:
        print("Usage: generate_doclog.py <prolog_file>", file=sys.stderr)
        sys.exit(1)
        
    filepath = sys.argv[1]
    module_name, exports = parse_exports(filepath)
    if not module_name:
        sys.exit(1)
        
    print("/**")
    print(f"  Documentation for module `{module_name}`.")
    print("*/")
    print()
    for exp in exports:
        print(make_template(exp))

if __name__ == "__main__":
    main()
