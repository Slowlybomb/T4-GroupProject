import os

def print_file_architecture(root_dir):
    """
    Recursively prints the file architecture of a given directory.
    """
    # Check if the directory exists
    if not os.path.exists(root_dir):
        print(f"Directory '{root_dir}' not found.")
        return

    print(f"Architecture of: {root_dir}")
    print("-" * len(f"Architecture of: {root_dir}"))

    # os.walk traverses the directory tree
    for root, dirs, files in os.walk(root_dir):
        # Calculate the current level of indentation
        level = root.replace(root_dir, '').count(os.sep)
        indent = ' ' * 4 * level
        
        # Print the current directory name
        print(f"{indent}[{os.path.basename(root)}/]")
        
        # Print the files in the current directory
        sub_indent = ' ' * 4 * (level + 1)
        for f in files:
            print(f"{sub_indent}{f}")

if __name__ == "__main__":
    # Define the target folder
    target_folder = '/lib'
    print_file_architecture(target_folder)