# Individual Swap Toggle Feature! ✅

## What Changed

Each duplicate group now has a **"Swap" button** that lets you reverse which event is kept vs deleted.

## How It Works

### Default Behavior:
- The system picks the "best" event to keep (most data)
- All other events for that date are marked for deletion
- **Green border** = KEEP
- **Red border** = DELETE

### Swap Button:
- Located next to each date header
- **Tap "Swap"** to reverse the selection
- The current "KEEP" becomes "DELETE"
- The first "DELETE" becomes "KEEP"

### For Multiple Duplicates:
If there are more than 2 events on a date:
- First tap: Swaps to the next event
- Each tap cycles through all events
- Eventually loops back to the original

## Visual Design

### Event to KEEP:
```
✓ KEEP (Green)
📍 Home
Note: Golf with Bob
2 activities  2 people
[Green border, thick]
```

### Events to DELETE:
```
🗑️ DELETE (Red)
📍 Loft  
Note: Pebble Beach
1 activities  0 people
[Red border, thin]
```

### Swap Button:
```
[Date]        [↕️ Swap]  [2 duplicate(s)]
```

## Example Usage

### Scenario: Most Are Correct
1. Scan and preview
2. Scroll through the list
3. Find the 3-4 anomalies where it picked wrong
4. Tap "Swap" on just those dates
5. Confirm deletion

### Scenario: Systematic Mistake
1. If the algorithm is backwards for a category
2. You can quickly tap "Swap" on each affected date
3. The visual feedback makes it easy to verify

## Real Example

**Before Swap:**
```
March 15, 2024          ↕️ Swap

✓ KEEP
📍 Loft [Wrong!]
Note: Pebble Beach

🗑️ DELETE  
📍 Home [Should keep this!]
Note: Golf tournament with friends
```

**After Tapping Swap:**
```
March 15, 2024          ↕️ Swap

✓ KEEP
📍 Home [Correct!]
Note: Golf tournament with friends

🗑️ DELETE
📍 Loft [Correct!]
Note: Pebble Beach
```

## Benefits

✅ **Quick fixes** - One tap to reverse
✅ **Visual clarity** - Borders show what will happen
✅ **No selection complexity** - Just swap wrong ones
✅ **Handles edge cases** - For dates with 3+ events
✅ **Undo-able** - Tap again to swap back

## Button Location

The Swap button is prominently placed in the header of each date group, making it easy to spot and tap while scrolling through the list.

Perfect for fixing the algorithm's mistakes! 🎯
