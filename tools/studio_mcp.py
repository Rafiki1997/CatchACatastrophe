"""Tiny stdio client for Roblox Studio's bundled StudioMCP.exe.

No Studio MCP server is configured for Claude, so this speaks JSON-RPC to the
exe directly. Run from the repository root:

  python tools/studio_mcp.py state
  python tools/studio_mcp.py play            # start Play
  python tools/studio_mcp.py stop            # stop Play
  python tools/studio_mcp.py exec tools/ui_audit.luau --dm Client [--prepend "AUDIT_SCALE = 0.7"]
  python tools/studio_mcp.py call screen_capture '{"capture_id": "hud"}' --out shot.png

The studio_id is discovered automatically (Studio can take ~15 s to answer the
first time); set STUDIO_ID to skip discovery. Set PYTHONIOENCODING=utf-8.
"""
import argparse
import base64
import glob
import json
import os
import re
import subprocess
import sys
import time

OFFICIAL_PLACE = "6f9cd136-faa6-4b44-b5bc-3f40ee0f50d9"
UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")


def find_exe():
    paths = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\StudioMCP.exe"))
    if not paths:
        sys.exit("StudioMCP.exe not found under %LOCALAPPDATA%/Roblox/Versions")
    return max(paths, key=os.path.getmtime)


class Client:
    def __init__(self):
        self.proc = subprocess.Popen(
            [find_exe()],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
        )
        self.next_id = 0
        self.request("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "cac-studio-mcp", "version": "1"},
        })
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def _send(self, message):
        self.proc.stdin.write(json.dumps(message) + "\n")
        self.proc.stdin.flush()

    def request(self, method, params=None):
        self.next_id += 1
        request_id = self.next_id
        self._send({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params or {}})
        while True:
            line = self.proc.stdout.readline()
            if not line:
                sys.exit(f"StudioMCP closed the pipe during {method}")
            message = json.loads(line)
            if message.get("id") == request_id:
                if "error" in message:
                    sys.exit(f"{method} failed: {message['error']}")
                return message["result"]

    def call(self, tool, arguments):
        return self.request("tools/call", {"name": tool, "arguments": arguments})

    def studio_id(self, timeout=60):
        if os.environ.get("STUDIO_ID"):
            return os.environ["STUDIO_ID"]
        deadline = time.time() + timeout
        while time.time() < deadline:
            ids = UUID.findall(text_of(self.call("list_roblox_studios", {})))
            if ids:
                return OFFICIAL_PLACE if OFFICIAL_PLACE in ids else ids[0]
            time.sleep(3)
        sys.exit("Roblox Studio did not answer; is it open with the MCP plugin enabled?")

    def close(self):
        self.proc.kill()


def text_of(result):
    return "\n".join(c.get("text", "") for c in result.get("content", []) if c.get("type") == "text")


def save_images(result, out):
    images = [c for c in result.get("content", []) if c.get("type") == "image"]
    for index, image in enumerate(images):
        path = out if len(images) == 1 else f"{os.path.splitext(out)[0]}_{index}{os.path.splitext(out)[1]}"
        with open(path, "wb") as handle:
            handle.write(base64.b64decode(image["data"]))
        print(f"saved {path}")
    return len(images)


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("state")
    sub.add_parser("play")
    sub.add_parser("stop")
    ex = sub.add_parser("exec")
    ex.add_argument("file")
    ex.add_argument("--dm", default="Client", choices=["Edit", "Server", "Client"])
    ex.add_argument("--prepend", default="")
    raw = sub.add_parser("call")
    raw.add_argument("tool")
    raw.add_argument("args", nargs="?", default="{}")
    raw.add_argument("--out", default="")
    opts = parser.parse_args()

    client = Client()
    try:
        sid = client.studio_id()
        if opts.cmd == "state":
            result = client.call("get_studio_state", {"studio_id": sid})
        elif opts.cmd in ("play", "stop"):
            result = client.call("start_stop_play", {"studio_id": sid, "is_start": opts.cmd == "play"})
        elif opts.cmd == "exec":
            with open(opts.file, encoding="utf-8") as handle:
                code = handle.read()
            if opts.prepend:
                code = opts.prepend + "\n" + code
            result = client.call("execute_luau", {"studio_id": sid, "datamodel_type": opts.dm, "code": code})
        else:
            arguments = json.loads(opts.args)
            arguments.setdefault("studio_id", sid)
            result = client.call(opts.tool, arguments)
        print(text_of(result))
        if opts.cmd == "call" and opts.out:
            if save_images(result, opts.out) == 0:
                print("no image content in the result")
        if result.get("isError"):
            sys.exit(1)
    finally:
        client.close()


if __name__ == "__main__":
    main()
