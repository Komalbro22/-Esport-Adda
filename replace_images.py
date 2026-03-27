import os
import re

directories = [
    r"c:\Users\KOMALPRRET\Desktop\esport\esport_user_app\lib",
    r"c:\Users\KOMALPRRET\Desktop\esport\esport_admin_app\lib"
]

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # If no Image.network, skip
    if 'Image.network' not in content:
        return

    # Replace Image.network(url, ...) with CachedNetworkImage(imageUrl: url, ...)
    # This regex looks for Image.network( followed by the first argument (which is the URL)
    # The URL could be a variable, string, or expression up to the next comma or closing paren.
    # It's tricky with nested parens, but most of these are simple like Image.network(_imageUrl!, ...)
    # Let's do a more robust approach. We can just replace Image.network( with CachedNetworkImage(imageUrl: 
    
    # A simple regex for Image.network(ARG, kwargs...) or Image.network(ARG)
    # We capture the first argument ARG which stops at comma or closing parenthesis IF there are no nested parentheses.
    # Actually, Dart formatting might have `Image.network( url, fit: ... )`.
    # Let's use a simpler string replacement approach if possible or a smart regex.
    
    new_content = re.sub(
        r'Image\.network\(\s*([^,)]+)', 
        r'CachedNetworkImage(imageUrl: \1', 
        content
    )
    
    # If we changed something, ensure import exists
    if new_content != content:
        import_stmt = "import 'package:cached_network_image/cached_network_image.dart';\n"
        if import_stmt.strip() not in new_content:
            # Add to top after other imports
            new_content = import_stmt + new_content
            
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {file_path}")

for directory in directories:
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                process_file(os.path.join(root, file))
