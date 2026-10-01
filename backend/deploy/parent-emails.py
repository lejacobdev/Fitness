#!/usr/bin/env python3
"""Sends due parent emails through this server's sendmail (Postfix, DKIM).

Cron (root):
  */10 * * * * /usr/bin/python3 /root/fitness/backend/deploy/parent-emails.py >> /var/log/fitness-parent-emails.log 2>&1
"""
import email.utils
import json
import subprocess
import sys
from datetime import datetime, timezone
from email.message import EmailMessage

CONTAINER = "student-athlete-api-1"
FROM = "AthleteOS <noreply@lejacob.dev>"


def script(*args):
    return subprocess.run(["docker", "exec", CONTAINER, "node", "src/scripts/parentEmails.js", *args],
                          check=True, capture_output=True, text=True).stdout


def main():
    for line in script("due").splitlines():
        if not line.strip():
            continue
        m = json.loads(line)
        msg = EmailMessage()
        msg["From"] = FROM
        msg["To"] = m["to"]
        msg["Subject"] = m["subject"]
        msg["Date"] = email.utils.formatdate(localtime=False)
        msg["Message-ID"] = email.utils.make_msgid(domain="lejacob.dev")
        if m.get("stop"):
            msg["List-Unsubscribe"] = "<" + m["stop"] + ">"
            msg["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
        msg.set_content(m["text"])
        if m.get("html"):
            msg.add_alternative(m["html"], subtype="html")
        subprocess.run(["/usr/sbin/sendmail", "-t", "-f", "noreply@lejacob.dev"], input=msg.as_bytes(), check=True)
        script("sent", m["kind"], m["athleteId"])
        print(f"{datetime.now(timezone.utc).isoformat()} sent {m['kind']} for {m['athleteId']}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as err:
        print(f"{datetime.now(timezone.utc).isoformat()} failed: {err} {err.stderr}", file=sys.stderr)
        sys.exit(1)
