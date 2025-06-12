# Automation Tool

A powerful automation tool built with AutoHotkey v2 for Windows to automate repetitive tasks through image recognition and click sequences.

## Features

- **Flow Management**: Create, edit, and run sequences of automated actions
- **Workflow Orchestration**: Combine multiple flows into comprehensive workflows
- **Action Recorder**: Capture your interactions and convert them into automated flows
- **Settings Management**: Customize the tool's behavior to suit your needs

## Action Recorder

The Action Recorder is a new feature that allows you to record your mouse interactions and automatically convert them into reusable automation flows.

### Getting Started with Action Recorder

1. Launch the Automation Tool
2. Navigate to the "Action Recorder" tab
3. Click "Start Recording" button or press `Ctrl+Alt+R` to begin recording
4. Perform the actions you want to record:
   - Every left-click will be automatically captured
   - Use `Ctrl+Alt+H` to capture hover positions without clicking
   - Use `Ctrl+Alt+I` for interactive capture of elements that change appearance on hover
5. Press `Ctrl+Alt+E` or click "Stop Recording" when finished
6. Enter a name for your recorded flow
7. The system will automatically save your recording and switch to the Flow Management tab where you can view and edit your new flow

### How it Works

- Each click or hover action captures a 100×100 pixel region centered on your cursor
- Images are saved to the `images` folder with timestamps
- Wait times between actions are automatically calculated
- All steps can be reviewed and edited before saving

### Recording Controls

| Action | Hotkey | Button | Description |
|--------|--------|--------|-------------|
| Start Recording | `Ctrl+Alt+R` | Start Recording | Begins capturing your mouse interactions |
| Capture Hover | `Ctrl+Alt+H` | Capture Hover | Captures the current mouse position without clicking |
| Interactive Capture | `Ctrl+Alt+I` | Interactive Capture | Shows a screenshot for you to click exactly where needed (for elements that change appearance on hover) |
| Stop Recording | `Ctrl+Alt+E` | Stop Recording | Ends the recording and prompts to save |

### Interactive Capture Feature

The Interactive Capture feature is designed for UI elements that change their visual state when hovered over:

1. Press `Ctrl+Alt+I` during recording
2. A full-screen screenshot will appear
3. Click on the exact location where you need the automation to click
4. The system will capture a 100×100 pixel region centered on your click point
5. Recording will then continue automatically

This is particularly useful for:
- Drop-down menus that only appear on hover
- Buttons that change appearance when the mouse is over them
- Elements that need precise timing between hover and click
- Any UI component with hover states or tooltips

### Managing Recorded Steps

While recording or after stopping, you can:

- **Remove Steps**: Select a step and click "Remove Selected" to delete it
- **Reorder Steps**: Use "Move Up" and "Move Down" buttons to change step order
- **Review Steps**: View all captured steps in the list with their wait times and images

### Tips for Effective Recording

1. Plan your sequence before recording to minimize errors
2. Move deliberately between actions to ensure accurate image captures
3. Use hover captures (`Ctrl+Alt+H`) for targets that need precise positioning
4. Use interactive captures (`Ctrl+Alt+I`) for elements that change appearance on hover
5. Record in the same visual environment where the automation will run
6. After saving, review the flow in the Flow Management tab and make any necessary adjustments

## Step Recorder (Coming Soon)

A new "Step Recorder" tab will allow you to quickly capture and save a single automation step for use in your flows. Stay tuned for updates!

## Additional Information

For more detailed documentation on other features, refer to the application's help section or contact your system administrator.

---

*This tool requires AutoHotkey v2.0.19 or later.* 