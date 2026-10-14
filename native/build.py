import hashlib
import json
import platform
import subprocess
from pathlib import Path


def main():
    root = Path(__file__).resolve().parent
    source = root / "dot_i8.c"
    library = root / ("libeat_dot.dylib" if platform.system() == "Darwin" else "libeat_dot.so")
    command = ["cc", "-O3", "-std=c11", "-dynamiclib" if platform.system() == "Darwin" else "-shared", "-fPIC"]
    if platform.machine().lower() in ["arm64", "aarch64"]:
        command.append("-march=armv8-a")
    command.extend([str(source), "-o", str(library)])
    subprocess.run(command, check=True)
    metadata = {"command": command, "platform": platform.platform(), "machine": platform.machine(),
                "compiler": subprocess.check_output(["cc", "--version"], text=True).splitlines()[0],
                "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "library_sha256": hashlib.sha256(library.read_bytes()).hexdigest(),
                "status": "local_reference_kernel_not_board_benchmark"}
    (root / "build_metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(str(library))


if __name__ == "__main__":
    main()
