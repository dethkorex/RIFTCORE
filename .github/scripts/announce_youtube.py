"""Notify Riftcore Discord about public uploads on the studio YouTube channel."""
import base64
import json
import os
import re
import subprocess
from datetime import datetime
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from xml.etree import ElementTree

CHANNEL = "UCcOsAr5bj_Drbe2XOXygbJA"
ANNOUNCEMENTS = "1572938413227778159"
BRANCH = "discord-feed-state"
ATOM = "{http://www.w3.org/2005/Atom}"
YT = "{http://www.youtube.com/xml/schemas/2015}"


def github(path, data=None):
    command = ["gh", "api", path]
    if data is not None:
        command.extend(["--method", "PUT", "--input", "-"])
    result = subprocess.run(command, input=json.dumps(data) if data else None,
                            text=True, capture_output=True, check=True)
    return json.loads(result.stdout)


def main():
    # Compare against a durable ledger so a delayed run can catch up.
    path = f"repos/{os.environ['GITHUB_REPOSITORY']}/contents/youtube-posts.json"
    record = github(f"{path}?ref={BRANCH}")
    state = json.loads(base64.b64decode(record["content"]))
    since = datetime.fromisoformat(state["since"])
    webhook = os.environ["DISCORD_YOUTUBE_WEBHOOK"].strip()
    with urlopen(Request(webhook, headers={"User-Agent": "Riftcore-Notifier/1"}), timeout=25) as response:
        if json.load(response)["channel_id"] != ANNOUNCEMENTS:
            raise ValueError("Discord destination does not match the announcements channel")
    feed_url = f"https://www.youtube.com/feeds/videos.xml?channel_id={CHANNEL}"
    with urlopen(Request(feed_url, headers={"User-Agent": "Riftcore-Notifier/1"}), timeout=25) as response:
        feed = ElementTree.parse(response).getroot()
    # YouTube sometimes omits the UC prefix on the feed itself.
    if feed.tag != ATOM + "feed" or feed.findtext(YT + "channelId") not in (CHANNEL, CHANNEL[2:]):
        raise ValueError("Unexpected YouTube feed")
    entries = sorted(feed.findall(ATOM + "entry"), key=lambda entry: entry.findtext(ATOM + "published"))
    sent = 0
    for entry in entries:
        video = entry.findtext(YT + "videoId", "")
        if not re.fullmatch(r"[A-Za-z0-9_-]{11}", video) or entry.findtext(YT + "channelId") != CHANNEL:
            raise ValueError("Unexpected video identity")
        published = datetime.fromisoformat(entry.findtext(ATOM + "published"))
        if video in state["posted"] or published < since:
            continue
        title = entry.findtext(ATOM + "title", "New studio video")
        payload = {"username": "Destructive Force Studio",
                   "content": f"**New on YouTube**\n{title}\nhttps://www.youtube.com/watch?v={video}",
                   "allowed_mentions": {"parse": []}}
        request = Request(webhook + "?wait=true", data=json.dumps(payload).encode(),
                          headers={"Content-Type": "application/json", "User-Agent": "Riftcore-Notifier/1"})
        with urlopen(request, timeout=30) as response:
            posted = json.load(response)
        if posted.get("channel_id") != ANNOUNCEMENTS or not posted.get("id"):
            raise ValueError("Discord did not acknowledge the post")
        state["posted"].append(video)
        content = base64.b64encode((json.dumps(state, indent=2) + "\n").encode()).decode()
        update = github(path, {"branch": BRANCH, "sha": record["sha"], "content": content,
                               "message": f"Record announced video {video}"})
        record = update["content"]
        sent += 1
    print(f"Verified Discord destination. Checked {len(entries)} studio uploads; announced {sent}.")


if __name__ == "__main__":
    try:
        main()
    except HTTPError as error:
        # A Discord webhook URL contains a credential. Keep URLs out of error output.
        raise SystemExit(f"Feed or Discord request failed with HTTP {error.code}") from None
