# /// script
# dependencies = [
#     "telethon>=1.42.0",
# ]
# ///
import os
import re
import json
import asyncio
import argparse
from telethon import TelegramClient
from telethon.errors import MessageNotModifiedError, MsgIdInvalidError, FloodWaitError

CONFIG_FILE = "tmp/config.txt"
DATA_DIR = "data"

YOUTUBE_REGEX = re.compile(
        r"^\S*(?:youtube\.com/(?:watch\?v=|shorts/)|youtu\.be/)([a-zA-Z0-9_-]{11})"
)

FILENAME_RE = re.compile(
        r'(?P<date>\d{8})-(?P<timestamp>\d+)-(?P<id>[a-zA-Z0-9_-]{11})-(?P<type>[a-z])-(?P<title>.+)\.description'
)

timestamp_pattern = re.compile(r'(\d\d?:)?\d\d?:\d\d')

# for case when you requested both --last 10 and some --ids,
# record ids of already seen videos, so not to search them with --ids later again
seen_ids=set()


def load_config():
    config = {}
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        for line in f:
            if "=" in line:
                k, v = line.split("=", 1)
                config[k.strip()] = v.strip()
    return config


def parse_descriptions():
    descriptions = {}

    for file in os.listdir(DATA_DIR):
        if not file.endswith(".description"):
            continue

        match = FILENAME_RE.match(file)
        if not match:
            print(f"Skipping unparsable filename: {file}")
            continue

        data = match.groupdict()
        video_id = data["id"]

        descriptions[video_id] = {
            "filename": file,
            "base": file[:-12],
            "date": data["date"],
            "type": data["type"],
            "title": data["title"]
        }

    return descriptions


def extract_video_id(text):
    m = re.search(YOUTUBE_REGEX, text)
    if m:
        return m.group(1)
    return None


def format_header(date, url, vtype, title):
    icons = {"v": "📹", "l": "📺", "s": "📱"}
    icon = icons.get(vtype, "📹")

    formatted_date = f"{date[:4]}-{date[4:6]}-{date[6:]}"
    return f"[{formatted_date}]({url}) {icon} **{title}**"


def to_seconds(comment):
    match = timestamp_pattern.search(comment['text'])
    parts = list(map(int, match.group().split(':')))

    # If format is MM:SS
    if len(parts) == 2:
        minutes, seconds = parts
        return minutes * 60 + seconds

    # If format is H:MM:SS
    if len(parts) == 3:
        hours, minutes, seconds = parts
        return hours * 3600 + minutes * 60 + seconds


def load_comments(json_file, first_comment=''):
    try:
        with open(json_file, "r", encoding="utf-8") as file:
            data = json.load(file)
    except json.decoder.JSONDecodeError:
        return []

    pinned_comments = [
        c for c in data.get('comments', [])
        if c.get('is_pinned')
    ]

    data_comments = []
    if first_comment:
        data_comments.append(first_comment)

    for pinned in pinned_comments:
        if timestamp_pattern.search(pinned.get('text', '')):
            data_comments.append(pinned['text'])

        children = [
            c for c in data['comments']
            if c.get('parent') == pinned['id']
            and timestamp_pattern.search(c.get('text', ''))
        ]

        children.sort(key=to_seconds)

        for child in children:
            data_comments.append(child['text'])

    return data_comments


async def delete_emoji_mirror_messages(client: TelegramClient, discussion_group_id):
    """
    Deletes discussion group mirror messages where:
    - The message contains '📱' (filtered by search)
    - '📱' is the second word
    - Has replies.channel_post (mirror messages)
    """
    pattern = re.compile(r'^\S+\s📱\s')  # First word (\S+), space, then 📱, space

    async for msg in client.iter_messages(
        discussion_group_id,
        search="📱",
    ):
        if msg.fwd_from and getattr(msg.fwd_from, 'channel_post', None):
            if msg.text and pattern.match(msg.text):
                print(f"Deleting discussion for {msg.text.replace('\n','\\n')}")
                await client.delete_messages(discussion_group_id, msg.id)
                await asyncio.sleep(1)

def parse_args():
    parser = argparse.ArgumentParser(description="Process comments")
    parser.add_argument( "--last", type=int,
        help="Number of last videos to re-check"
    )
    parser.add_argument( "ids", nargs="*", default=[],
        help="video ids to re-check (actually re-check one video per argument with this text in description)"
    )
    parser.add_argument( "--all", action="store_true",
        help="re-check all videos"
    )
    return parser.parse_args()


async def process_msg(msg, client):
    if not msg.text:
        return
    video_id = extract_video_id(msg.text)
    if not video_id:
        print(f"no video in message {msg.text[:100].replace('\n','\\n')}")
        return
    seen_ids.add(video_id)
    if video_id not in descriptions:
        print(f"Missing description for {video_id}")
        return
    meta = descriptions[video_id]

    print(f"looking at {msg.text[:100].replace('\n','\\n')}")

    desc_path = os.path.join(DATA_DIR, meta["filename"])
    with open(desc_path, "r", encoding="utf-8") as f:
        # file_desc = '\n'.join(line.strip() for line in f)
        file_desc = [line.strip() for line in f]
        # file_desc = f.read()

    old_text = '\n'.join(line.strip() for line in msg.text.splitlines())
    title_line,_,old_desc = [part.strip() for part in old_text.partition('\n')]

    # new_text = title_line + "\n" + file_desc
    new_text = [title_line] + file_desc
    first_comment=''
    if len('\n'.join(new_text))>1000:
        first_comment='\n'.join(file_desc)
        while len('\n'.join(new_text))>1000:
            middle_index = len(new_text) // 2
            new_text.pop(middle_index)
        new_text.insert(middle_index, '\n[…]\n')
    new_text = '\n'.join(new_text).strip()

    # url_match = re.search(r'(https?://\S+)', msg.text)
    # url = url_match.group(1) if url_match else ""
    # header = format_header(meta["date"], url, meta["type"], meta["title"])

    if old_text.strip() != new_text:
        # new_text = header + "\n" + file_desc
        while True:
            try:
                print(f"========== Updating message from:\n{old_text}\n----- to[{len(new_text)}]:\n{new_text}")
                await msg.edit(new_text)
                await asyncio.sleep(1)
                # print(f"Updated message {msg.id}")
                break  # success, exit the loop
            except MessageNotModifiedError:
                break  # success, exit the loop
            except FloodWaitError as e:
                wait_time = e.seconds
                print(f"Flood wait: sleeping for {wait_time} seconds before retrying")
                await asyncio.sleep(wait_time)
            except Exception as e:
                print(f"Edit failed: {e}")
                break  # give up on other errors

    # ---- COMMENTS ----
    json_path = os.path.join(DATA_DIR, meta["base"] + ".comments.json")
    if meta['type']=='s':
        return
    if not os.path.exists(json_path):
        return
    data_comments = load_comments(json_path, first_comment)
    if not data_comments:
        return

    if not (msg.replies and msg.replies.comments):
        print(f"no discussion for msg {msg.text[:100].replace('\n','\\n')}")
        return
    try:
        replies = await client.get_messages(channel, limit=len(data_comments), reverse=True, reply_to=msg.id)
    except MsgIdInvalidError:
        print(f"no comments to message: {msg.text[:100].replace('\n','\\n')}")
        return

    for i, expected in enumerate(data_comments):
        expected = '\n'.join(line.strip() for line in expected.splitlines())
        if i < len(replies):
            actual = '\n'.join(line.strip() for line in replies[i].text.splitlines())
            if actual != expected:
                while True:
                    try:
                        print(f"========== Updating comment {i} from:\n{actual}\n----- to:\n{expected}")
                        # await replies[i].edit(expected)
                        await client.edit_message(discussion, replies[i], expected)
                        await asyncio.sleep(1)
                        # print(f"Edited comment {replies[i].id}")
                        break  # success, exit the loop
                    except FloodWaitError as e:
                        wait_time = e.seconds
                        print(f"Flood wait: sleeping for {wait_time} seconds before retrying")
                        await asyncio.sleep(wait_time)
                    except Exception as e:
                        print(f"Failed to edit comment, deleting: {e}")
                        try:
                            await replies[i].delete()
                        except:
                            print(f"Failed to delete comment: {e}")
                        break  # give up on other errors
          # else:
          #     print(f"ok reply {i}")
        else:
            while True:
                try:
                    print(f"========== Adding comment {i} to {msg.text[:100].replace('\n','\\n')}:\n{expected}")
                    await client.send_message(channel, expected, comment_to=msg.id)
                    break  # success, exit the loop
                except FloodWaitError as e:
                    wait_time = e.seconds
                    print(f"Flood wait: sleeping for {wait_time} seconds before retrying")
                    await asyncio.sleep(wait_time)
                except Exception as e:
                    print(f"Failed to add comment: {e}")
                    break  # give up on other errors


async def main(args):
    async with TelegramClient("tmp/session", api_id, api_hash) as client:

        await delete_emoji_mirror_messages(client, discussion)

        if args.last or args.all:
            async for msg in client.iter_messages(channel, limit=None if args.all else args.last):
                await process_msg(msg, client)

        for video_id in args.ids:
            if video_id in seen_ids:
                continue
            found = False
            async for msg in client.iter_messages(channel, search=video_id, limit=1):
                found = True
                await process_msg(msg, client)
            if not found:
                print(f"No messages with [{video_id}].")

if __name__ == "__main__":
    args = parse_args()

    config = load_config()
    api_id = int(config["api_id"])
    api_hash = config["api_hash"]
    channel = int(config["channel"])
    discussion = int(config.get("discussion_channel"))

    descriptions = parse_descriptions()

    asyncio.run(main(args))
