#!/usr/bin/env python3
"""Resolve Xcode's real object names while retaining the game's source order."""
import shlex
import sys
import os
from pathlib import Path


def main():
    manifest, build_root, configuration, architecture, output = sys.argv[1:]
    sources = [(module, os.path.normpath(source)) for module, source in
               (line.split("\t") for line in Path(manifest).read_text().splitlines())]
    wanted = {source for _, source in sources}
    objects = {}
    for module in dict.fromkeys(module for module, _ in sources):
        directory = Path(build_root).resolve() / f"{module}.build" / configuration / "Objects-normal" / architecture
        for dependency in directory.glob("*.d"):
            tokens = {os.path.normpath(token) for token in
                      shlex.split(dependency.read_text().replace("\\\n", ""))}
            for source in wanted.intersection(tokens):
                obj = dependency.with_suffix(".o")
                if obj.is_file():
                    key = (module, source)
                    if key in objects and objects[key] != obj:
                        raise RuntimeError(f"Ambiguous objects for {source}")
                    objects[key] = obj
    missing = [source for module, source in sources if (module, source) not in objects]
    if missing:
        raise RuntimeError("Missing Xcode objects: " + ", ".join(missing))
    destination = Path(output)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("".join(f'"{objects[module, source]}"\n' for module, source in sources))


if __name__ == "__main__":
    main()
