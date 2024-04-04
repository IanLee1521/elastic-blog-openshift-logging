import jinja2
import yaml
import json
import os

def read_files_in_directory(directory: str) -> dict:
    file_content_map = {}
    for root, _, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            with open(file_path, 'r',) as f:
                content = f.read()
                file_content_map[file_path] = content
    return file_content_map 

def toJson(input, indent=2):
    yaml_data = yaml.safe_load(input)
    return json.dumps(yaml_data, indent=indent)

environment = jinja2.Environment(loader=jinja2.FileSystemLoader("./"), trim_blocks=True)

environment.filters["json"] = toJson

variables = {
    "elk": read_files_in_directory("./elk"),
    "openshift": read_files_in_directory("./openshift")
}

lt = environment.list_templates(extensions=["j2"])

for template in lt:
    print(f"Rendering template {template}")
    output_file = os.path.splitext(template)[0]
    with open(f"{output_file}", "w") as f:
        f.write(environment.get_template(template).render(**variables))