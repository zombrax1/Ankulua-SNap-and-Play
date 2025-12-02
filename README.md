# Snap & Play Recorder (AnkuLua)

Single-file AnkuLua **Snap & Play recorder** that lets you record clicks/swipes as images and regions, then auto-generates a clean `.lua` script using `SearchImageNew`, `ClickImg`, and `WaitExists`.

- Record once by tapping/dragging on the screen.
- Tool saves PNG snapshots + steps.
- When you’re done, it builds a runnable script: `YourProject.lua` + `YourProject/` images.

---

## Features

- 🧩 **Single-file recorder**  
  Just one main script (`snapYourScript_fixed.lua`) plus your helper libs.

- 📁 **Per-project folder structure**
  - Images saved into: `./<FolderName>/`
  - Generated script: `./<FolderName>.lua`
  - Script and image folder stay together.

- 🎯 **Region-aware recording**
  - Automatically maps clicks to regions:
    - `Upper_Left`, `Upper_Right`
    - `Lower_Left`, `Lower_Right`
    - `Upper_Half`, `Lower_Half`
    - `Lower_Most_Half`
    - `Agnes_Region` (custom left-side region)
  - Generated code uses those regions in `ClickImg` / `WaitExists`.

- 🖼️ **Image-based search**
  - Uses `SearchImageNew()` internally for all detection.
  - Generated script includes:
    - `SearchImageNew`
    - `ClickImg`
    - `WaitExists`
  - Supports color / mask matching (params wired into helpers).

- 🧪 **Actions supported**
  From the main menu:

  1. **Find Image & Click**  
     - Draw a box → snapshot PNG.  
     - Generates:
       ```lua
       ClickImg("yourImage.png", Some_Region, CFG_ACCURACY, false, false, 5)
       ```

  2. **Find Image & Wait**  
     - Wait until image appears before moving on.  
     - Generates:
       ```lua
       WaitExists("yourImage.png", 20, Some_Region, CFG_ACCURACY, false, false)
       ```

  3. **Click Region (box)**  
     - Draw a box → click its center.  
     - Generates:
       ```lua
       click(Location(x, y))
       ```

  4. **Swipe (drag)**  
     - Perform a swipe gesture.  
     - Generates:
       ```lua
       swipe(Location(x1, y1), Location(x2, y2), 30)
       ```

  5. **Wait Seconds**  
     - Simple delay.  
     - Generates:
       ```lua
       wait(N)
       ```

  6. **If Image A then B**  
     - Define two images with regions.  
     - Generates:
       ```lua
       if WaitExists("A.png", 3, RegionA, CFG_ACCURACY, false, false) then
           ClickImg("A.png", RegionA, CFG_ACCURACY, false, false, 0)
       else
           ClickImg("B.png", RegionB, CFG_ACCURACY, false, false, 0)
       end
       ```

- 👀 **Visual preview helpers**
  - Region selection highlights what you selected.
  - Swipe preview boxes at start/end so you can see what was captured.

- 📏 **Resolution-aware**
  - Uses `Settings:setScriptDimension` and `Settings:setCompareDimension` so recordings stick to the current resolution.
  - Supports **immersive mode** if your game uses full-screen.

---

## Requirements

- **AnkuLua** (full or trial).
- Android device or emulator (LDPlayer, MuMu, Bluestacks, etc.).
- This script expects the helper libraries in the same folder:
  - `commonLib.lua`
  - `luaLib.lua`  
  (These provide things like `simpleDialog`, `Timer`, `Press`, etc.)

---

## Setup

1. Copy the recorder script and helper libs into your AnkuLua script folder:
   ```text
   /AnkuLua/scripts/
       snapYourScript_fixed.lua
       commonLib.lua
       luaLib.lua
