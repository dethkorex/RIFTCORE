"""Publish the notes of newly published Riftcore releases to the patch channel."""
import base64
import json
import os
import subprocess
from datetime import datetime
from urllib.error import HTTPError
from urllib.request import Request, urlopen

CHANNEL = "1572939176935030814"
GUILD = "1572937966224015391"
STATE_BRANCH = "discord-feed-state"


def github(path, data=None, paginate=False):
    command = ["gh", "api", path]
    if paginate:
        command.extend(["--paginate", "--slurp"])
    if data is not None:
        command.extend(["--method", "PUT", "--input", "-"])
    result = subprocess.run(command, input=json.dumps(data) if data else None,
                            text=True, capture_output=True, check=True)
    return json.loads(result.stdout)


def discord(url, payload=None):
    request = Request(url, headers={"User-Agent": "Riftcore-Notifier/1", "Content-Type": "application/json"},
                      data=json.dumps(payload).encode() if payload is not None else None)
    with urlopen(request, timeout=30) as response:
        return json.load(response)


def release_embed(release):
    notes = (release["body"] or "").strip()
    if len(notes) > 3900:
        excerpt = notes[:3850]
        boundary = excerpt.rfind("\n")
        excerpt = excerpt[:boundary] if boundary > 2900 else excerpt.rsplit(" ", 1)[0]
        notes = excerpt.rstrip() + "\n\nSee the full changelog on GitHub."
    return {"title": (release["name"] or release["tag_name"])[:256], "url": release["html_url"],
            "description": notes or "Open the release on GitHub for details.",
            "color": 0x2CD9EB, "timestamp": release["published_at"],
            "footer": {"text": "RIFTCORE  •  " + ("Prerelease" if release["prerelease"] else "Release")}}


def main():
    repo = os.environ["GITHUB_REPOSITORY"]
    webhook = os.environ["DISCORD_PATCH_WEBHOOK"].strip()
    destination = discord(webhook)
    if destination.get("guild_id") != GUILD or destination.get("channel_id") != CHANNEL:
        raise ValueError("Unexpected patch-notes destination")
    path = f"repos/{repo}/contents/release-posts.json"
    record = github(f"{path}?ref={STATE_BRANCH}")
    state = json.loads(base64.b64decode(record["content"]))
    since = datetime.fromisoformat(state["since"])
    pages = github(f"repos/{repo}/releases?per_page=100", paginate=True)
    releases = sorted((r for page in pages for r in page if not r["draft"] and r["published_at"]),
                      key=lambda r: r["published_at"])
    sent = 0
    for release in releases:
        key = str(release["id"])
        if key in state["posted"] or datetime.fromisoformat(release["published_at"]) < since:
            continue
        embed = release_embed(release)
        message = discord(webhook + "?wait=true", {"username": "RIFTCORE Patch Notes", "embeds": [embed],
                                                   "allowed_mentions": {"parse": []}})
        if message.get("channel_id") != CHANNEL or not message.get("id"):
            raise ValueError("Discord did not acknowledge the release")
        state["posted"].append(key)
        content = base64.b64encode((json.dumps(state, indent=2) + "\n").encode()).decode()
        record = github(path, {"branch": STATE_BRANCH, "sha": record["sha"], "content": content,
                               "message": f"Record Discord release announcement {key}"})["content"]
        saved = discord(f"{webhook}/messages/{message['id']}")
        if saved["embeds"][0].get("description") != embed["description"]:
            raise ValueError("Discord changelog readback did not match release notes")
        print(f"Verified changelog: https://discord.com/channels/{GUILD}/{CHANNEL}/{message['id']}")
        sent += 1
    print(f"Announced {sent} releases.")


if __name__ == "__main__":
    try:
        main()
    except HTTPError as error:
        raise SystemExit(f"Discord returned HTTP {error.code}") from None
