---
description: Handle disconnection or error recovery with context restoration
---

# /disconnection or /error Workflow

When user reports a disconnection, error, or session interruption.

## Steps

1. **Acknowledge the Issue**

   ```
   Understand this is a recovery situation.
   Don't repeat actions that may have caused the issue.
   ```

2. **Check Available Logs**

   ```
   Review .system_generated/logs/ for:
   - Last successful actions
   - Any error patterns
   - Where conversation broke
   ```

3. **Query Memory State**

   ```
   mcp-memory provides:
   - Last known task
   - Recent observations
   - Key context
   ```

4. **Identify Potential Causes**

   Common disconnection causes:

   | Cause | Symptoms | Solution |
   |-------|----------|----------|
   | Token limit | Long outputs | Compress context, shorter responses |
   | Rate limit | Too many API calls | Pace requests, rotate accounts |
   | Parsing error | Malformed output | Simplify responses, avoid nested JSON |
   | Network timeout | Long operations | Break into smaller steps |
   | Context overflow | Too much context | Summarize and offload to files |

5. **Request User Context**

   ```markdown
   ## Recovery Mode 🔧

   ### What I Found
   - Last checkpoint: [timestamp]
   - Last task: [task name]
   - Status: [what I know]

   ### Possible Cause
   - [likely cause based on logs]

   ### Need From You
   1. What were we discussing when it failed?
   2. Did you see any error message?
   3. Approximately when did it disconnect?

   This helps me avoid repeating the issue.
   ```

6. **Apply Prevention Measures**

   Based on cause:

   ```yaml
   if: token_limit
   then:
     - Enable context compression
     - Summarize before long responses
     - Use filesystem-context skill

   if: rate_limit
   then:
     - Distribute across accounts (15+ Google Pro)
     - Add delays between calls
     - Batch operations

   if: parsing_error
   then:
     - Simplify output format
     - Avoid deeply nested structures
     - Test output formatting

   if: timeout
   then:
     - Use background processes
     - Checkpoint frequently
     - Break into smaller steps
   ```

7. **Resume Carefully**
   - Don't immediately repeat last action
   - Verify state before continuing
   - Proceed with smaller steps

## Prevention Strategies

### Checkpoint Frequently

Save state every major step, not just at end.

### Use Background Processes

Long operations should run async.

### Monitor Context Size

If conversation is long, summarize proactively.

### Distribute Load

Use multiple accounts for API-heavy tasks.

## Recovery Checklist

- [ ] Checked logs for error details
- [ ] Queried memory for last state
- [ ] Asked user for context
- [ ] Identified likely cause
- [ ] Applied prevention measures
- [ ] Confirmed with user before continuing
