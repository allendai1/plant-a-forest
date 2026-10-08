"""Print Luau that writes src/ files into the open Studio place.

Run the output with the Studio MCP connection (execute_luau, Edit datamodel).
Mapping follows default.project.json: src/shared -> ReplicatedStorage.Shared,
src/server -> ServerScriptService.Server, src/client -> StarterPlayerScripts.Client.
Folders become Folders, init.server/init.client become the root Script/LocalScript,
other .luau files become ModuleScripts. Deleted files are not removed from Studio.

Usage: python tools/studio_sync.py [--fetch] [file ...]   (default: every .luau file under src/)
  --fetch: instead of pasting file contents, Studio downloads each file from a local server
           (start it from the repo root: python -m http.server 34877 --bind 127.0.0.1)
"""

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TARGETS = {
    "shared": ('game:GetService("ReplicatedStorage")', "Shared", "Folder"),
    "server": ('game:GetService("ServerScriptService")', "Server", "Script"),
    "client": ('game:GetService("StarterPlayer").StarterPlayerScripts', "Client", "LocalScript"),
}

HEADER = """local function ensure(parent: Instance, name: string, class: string): Instance
	local inst = parent:FindFirstChild(name)
	if inst and inst.ClassName ~= class then
		local replacement = Instance.new(class)
		replacement.Name = name
		for _, child in inst:GetChildren() do
			child.Parent = replacement
		end
		inst:Destroy()
		replacement.Parent = parent
		return replacement
	end
	if not inst then
		inst = Instance.new(class)
		inst.Name = name
		inst.Parent = parent
	end
	return inst :: Instance
end
local written = 0
"""


def long_string(text: str) -> str:
    level = 1
    while f"]{'=' * level}]" in text:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{text}]{eq}]"


def statements(path: pathlib.Path) -> str:
    rel = path.resolve().relative_to(ROOT / "src")
    service, root_name, root_class = TARGETS[rel.parts[0]]
    lines = [f'local node = ensure({service}, "{root_name}", "{root_class}")']
    *dirs, filename = rel.parts[1:]
    for folder in dirs:
        lines.append(f'node = ensure(node, "{folder}", "Folder")')
    if filename.startswith("init."):
        target = "node"
    else:
        stem = filename.removesuffix(".luau")
        cls = "ModuleScript"
        if stem.endswith(".server"):
            stem, cls = stem.removesuffix(".server"), "Script"
        elif stem.endswith(".client"):
            stem, cls = stem.removesuffix(".client"), "LocalScript"
        target = f'ensure(node, "{stem}", "{cls}")'
    source = path.read_text(encoding="utf-8")
    lines.append(f"local script: any = {target}")
    lines.append(f"script.Source = {long_string(source)}")
    lines.append("written += 1")
    return "do\n" + "\n".join(lines) + "\nend"


FETCH_URL = "http://127.0.0.1:34877/"  # python -m http.server 34877 --bind 127.0.0.1, run from the repo root


def fetch_statements(path: pathlib.Path) -> str:
    """Like statements(), but Studio downloads the file from the local server: no file content is pasted."""
    rel = path.resolve().relative_to(ROOT).as_posix()
    head = statements(path).split("script.Source = ")[0]
    size = len(path.read_bytes())
    return (
        head
        + f'local body = game:GetService("HttpService"):GetAsync("{FETCH_URL}{rel}", true)\n'
        + f'assert(#body == {size}, "{rel}: got " .. #body .. " bytes, expected {size}")\n'
        + "script.Source = body\nwritten += 1\nend"
    )


def main() -> None:
    args = sys.argv[1:]
    fetch = "--fetch" in args
    args = [a for a in args if a != "--fetch"]
    files = [pathlib.Path(p) for p in args] or sorted((ROOT / "src").rglob("*.luau"))
    body = "\n".join((fetch_statements if fetch else statements)(f) for f in files)
    sys.stdout.reconfigure(encoding="utf-8")  # Windows consoles default to cp1252
    sys.stdout.write(HEADER + body + '\nreturn `synced {written} files`\n')


if __name__ == "__main__":
    main()
