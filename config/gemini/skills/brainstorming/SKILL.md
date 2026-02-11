---
name: brainstorming
description: "REQUIRED before any creative work - creating features, building components, adding functionality. Explores user intent, requirements and design before implementation."
keywords: [brainstorm, design, plan, requirements, explore, feature, idea]
disable-model-invocation: true
---

# Brainstorming Ideas Into Designs

## Overview

Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design in small sections (200-300 words), checking after each section whether it looks right so far.

## When to Use

> [!IMPORTANT]
> Use BEFORE any creative work: creating features, building components, adding functionality, or modifying behavior.

## The Process

### Understanding the Idea

1. Check current project state (files, docs, recent commits)
2. Ask questions **one at a time** to refine the idea
3. Prefer multiple choice questions when possible
4. Focus on: purpose, constraints, success criteria

### Exploring Approaches

1. Propose 2-3 different approaches with trade-offs
2. Lead with your recommended option and explain why
3. Let user choose before proceeding

### Presenting the Design

1. Break into sections of 200-300 words
2. Ask after each section: "Does this look right so far?"
3. Cover: architecture, components, data flow, error handling, testing
4. Be ready to go back and clarify

## Key Principles

| Principle | Description |
|-----------|-------------|
| **One question at a time** | Don't overwhelm with multiple questions |
| **Multiple choice preferred** | Easier to answer than open-ended |
| **YAGNI ruthlessly** | Remove unnecessary features from all designs |
| **Explore alternatives** | Always propose 2-3 approaches before settling |
| **Incremental validation** | Present design in sections, validate each |

## After the Design

1. Write validated design to `docs/plans/YYYY-MM-DD-<topic>-design.md`
2. Commit the design document
3. Ask: "Ready to set up for implementation?"
4. Create isolated workspace (worktree)
5. Create detailed implementation plan

## Anti-Patterns

- Jumping straight to code without exploring requirements
- Asking 5 questions at once
- Presenting complete design without incremental validation
- Skipping trade-off exploration
