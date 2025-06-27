# Thanks to @thatstoasty for the original code.

import tomllib
import os
from typing import Any
from pathlib import Path

import yaml


TEMP_DIR = Path(os.path.expandvars("$HOME/tmp"))
PIXI_TOML_PATH = Path("pixi.toml")
RECIPE_PATH = Path("recipe.yaml")
CONDA_BUILD_PATH = Path(os.environ.get("CONDA_BLD_PATH", os.getcwd()))
"""If `CONDA_BLD_PATH` is set, then publish from there. Otherwise, publish from the current directory."""


def load_project_config() -> dict[str, Any]:
    """Loads the project configuration from the pixi.toml file."""
    with PIXI_TOML_PATH.open("rb") as f:
        return tomllib.load(f)


PROJECT_CONFIG = load_project_config()


def format_dependency(name: str, version: str) -> str:
    """Converts the list of dependencies from the pixi.toml into a list of strings for the recipe."""
    start = 0
    operator = "=="
    if version[0] in {"<", ">"}:
        if version[1] != "=":
            operator = version[0]
            start = 1
        else:
            operator = version[:2]
            start = 2

    return f"{name} {operator} {version[start:]}"


def generate_recipe() -> None:
    """Generates a recipe for the project based on the project configuration in the pixi.toml."""
    # Replace the placeholders in the recipe with the project configuration.
    recipe = {
        "context": {"version": "13.4.2"},
        "package": {},
        "source": [],
        "build": {
            "script": [
                "mkdir -p ${PREFIX}/lib/mojo",
            ]
        },
        "requirements": {"run": []},
        "about": {},
    }

    # Populate package information
    package_name = "mojo-regex"
    recipe["package"]["name"] = PROJECT_CONFIG["package"]["name"]
    recipe["package"]["version"] = PROJECT_CONFIG["package"]["version"]

    # Populate source files
    recipe["source"].append({"path": "src"})
    recipe["source"].append({"path": PROJECT_CONFIG["workspace"]["license-file"]})

    # Populate build script
    recipe["build"]["script"].append(
        f"pixi run mojo package {package_name} -o ${{PREFIX}}/lib/mojo/{package_name}.mojopkg"
    )

    # Populate requirements
    for dependency, version in PROJECT_CONFIG["dependencies"].items():
        recipe["requirements"]["run"].append(format_dependency(dependency, version))

    # Populate about section
    recipe["about"]["homepage"] = PROJECT_CONFIG["workspace"]["homepage"]
    recipe["about"]["license"] = PROJECT_CONFIG["workspace"]["license"]
    recipe["about"]["license_file"] = PROJECT_CONFIG["workspace"]["license-file"]
    recipe["about"]["summary"] = PROJECT_CONFIG["workspace"]["description"]
    recipe["about"]["description"] = Path("README.md").read_text()
    recipe["about"]["repository"] = PROJECT_CONFIG["workspace"]["repository"]

    # Write the final recipe.
    with Path("recipe.yaml").open("w+") as f:
        yaml.dump(recipe, f)


if __name__ == "__main__":
    generate_recipe()
