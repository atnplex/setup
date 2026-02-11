# R55: Cross-Conversation Backlog

> Maintain a global backlog for task tracking across conversations.

## Location

`/atn/.gemini/scratch/backlog.md`

## When to Update

### On Task Added

- Add to "Pending Tasks" table
- Include: date, conversation ID (first 8 chars), status 🔴

### On Task Started

- Update status to 🟡 In Progress

### On Task Completed

- Move to "Completed Tasks" table
- Link any artifacts created

### On Learning Discovered

- Add to "Learnings & Optimizations" section
- Include date and brief summary

## Purpose

1. Cross-conversation visibility
2. Backtrack to incomplete tasks
3. Avoid duplicate work
4. Track infrastructure decisions

## Access

All agents should check backlog at conversation start if:

- User references prior work
- Task seems related to previous conversations
- Checking for pending items
