---
name: set-topic
description: Set or change the session topic displayed in the statusline
argument-hint: <topic text>
allowed-tools: [Bash]
version: "4.0.0"
---

Set the session topic to: $ARGUMENTS

If the text is empty, tell the user to provide a topic (e.g., `/set-topic Auth Refactor`).

Follow the **Manual Override** instructions in the auto-topic skill to sanitize and write this topic, then confirm to the user.
