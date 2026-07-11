# ParseVis

**ParseVis** is a next-generation combat parsing addon for Final Fantasy XI (Windower 4) that visualizes your party's performance via an external, interactive web dashboard. 

Unlike traditional parsing addons that rely on in-game text displays, ParseVis silently logs combat events in the background and writes them to a local file, allowing you to view detailed analytics, graphs, and breakdowns in your web browser with zero configuration.

## Features

*   **Zero-Config Dashboard**: No Node.js or Python web servers required. Just double-click the HTML file to view your stats.
*   **Offensive Metrics**: Track Damage Over Time, Damage Breakdowns (Melee vs Magic vs WS), Weaponskill Averages, and Hit/Miss Accuracy per player.
*   **Defensive Metrics**: Track Damage Taken, Evasion (Misses vs Hits), and Healing done per player (including Job Abilities like Curing Waltz!).
*   **Modern Aesthetics**: The dashboard is built with a premium dark-mode, glassmorphic design and uses Chart.js for smooth, animated canvas graphing.
*   **Time-Series Logging**: Captures every swing, spell, and heal with exact timestamps to generate rich historical data.

## Installation & Usage

1. Download or clone this repository.
2. Place the `ParseVis` folder into your `Windower4/addons/` directory.
3. In game, type `//lua load ParseVis`.
4. Open the dashboard by navigating to your `Windower4/addons/ParseVis/html/` folder and double-clicking `index.html` in your web browser (Chrome, Firefox, Safari).

*Note: The addon automatically exports data every 20 seconds to keep your dashboard updated. Simply refresh your browser tab to see the latest data!*

## Commands

Use `//parsevis` or `//pv` followed by a command:

*   `//pv report` - Manually export the latest data to the dashboard immediately.
*   `//pv reset` - Clear all combat data from the current session.
*   `//pv silent` - Toggle the auto-export chat log message on and off.
*   `//pv debug` - Toggle debug mode to print raw packet IDs to the chat (useful for tracking down elusive Job Ability messages).
*   `//pv help` - Show the in-game help menu.

## How It Works

ParseVis intercepts action packets (`0x28`) and logs them into a Lua array. This array is serialized to a JSON string and saved into `html/data.js` as a global JavaScript variable. Because it exports to `.js` rather than `.json`, local browsers bypass CORS restrictions, allowing the `index.html` file to be opened directly without a web server.
