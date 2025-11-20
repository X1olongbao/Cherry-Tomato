# Database Schema Update for Preset Mode

## Summary
Added support for tracking which Pomodoro preset mode was used when completing a session (Classic Pomodoro, Long Study Mode, Quick Task Mode, or Custom Mode).

## Changes Made

### ✅ Local SQLite Database (Automatic)
- **Version**: Updated from 2 to 3
- **Migration**: Automatically adds `preset_mode` column to `sessions` table
- **No action needed** - The app will automatically upgrade existing databases

### ⚠️ Supabase Remote Database (Manual Action Required)

You need to add the `preset_mode` column to your Supabase `pomodoro_sessions` table.

## SQL to Run in Supabase

Go to your Supabase Dashboard → SQL Editor and run:

```sql
-- Add preset_mode column to pomodoro_sessions table
ALTER TABLE pomodoro_sessions 
ADD COLUMN IF NOT EXISTS preset_mode TEXT;

-- Optional: Add a comment to document the column
COMMENT ON COLUMN pomodoro_sessions.preset_mode IS 
  'Preset mode used: classic, longStudy, quickTask, or custom';
```

## Column Details

- **Column Name**: `preset_mode`
- **Type**: `TEXT` (nullable)
- **Possible Values**:
  - `'classic'` - Classic Pomodoro mode
  - `'longStudy'` - Long Study Mode
  - `'quickTask'` - Quick Task Mode
  - `'custom'` - Custom Mode
  - `NULL` - For old sessions created before this feature

## What Changed in Code

1. ✅ **PomodoroSession Model** - Added `presetMode` field
2. ✅ **Database Service** - Updated schema version and migration
3. ✅ **Session Service** - Now accepts and stores preset mode
4. ✅ **Pomodoro Timer** - Passes preset mode when recording sessions
5. ✅ **Session History Page** - Displays preset mode in history

## Testing

After running the SQL:
1. Complete a Pomodoro session in different modes
2. Check the session history - you should see the mode displayed
3. Verify the mode is saved correctly in both local and remote databases

## Backward Compatibility

- Old sessions without `preset_mode` will show as "Classic Pomodoro" (default)
- The column is nullable, so existing data is not affected
- New sessions will always have the preset mode recorded

