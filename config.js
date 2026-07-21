// Colors now live in Colors.qml (pywal-driven singleton)

const bar = {
    fontFamily: "Mononoki Nerd Font",
    fontSize: 22,
    height: 30
}

// Unified text-size scale (Tab 0 and onward)
const type = {
    micro: 12,   // tiny meta text (map attribution, fine print)
    label: 14,   // section headers: "HARDWARE", "WEATHER", "QUICK TOGGLES"
    sm: 16,      // secondary/meta text
    base: 18,    // default body text
    md: 20,      // emphasized text
    lg: 22,      // primary size (matches bar.fontSize)
    xl: 26,      // sub-headers, control icons
    display: 36, // large icons / big numbers
    hero: 72,    // hero-sized numbers (e.g. the weather temperature)
}

// Unified spacing/margin scale
const gap = {
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 20,
    xxl: 28,
}

// Unified corner-radius scale (proportional/circle cases stay literal, not tokenized)
const radius = {
    xs: 3,   // thin bars
    sm: 4,   // small chips/thumbnails
    md: 6,   // small pills (tab highlight, HUD)
    lg: 8,   // toggle tiles, inset panels
    xl: 10,  // primary cards
    xxl: 12, // larger cards (Tab 2 media card)
}


const notifications = {
    timeout: 7000
}

const timer = {
    interval: 1000,              // general UI tick (clock, progress displays)
    weatherRefresh: 600000,      // 10 min
    hardwareRefresh: 2000,       // Tab 0 hardware mini-chart polling
    mapSettle: 500,              // precip map: pause after pan/zoom before prefetching
    mapPrefetchStagger: 1200,    // precip map: gap between warming each radar frame
    radarFrameAdvance: 650,      // radar loop: ms per frame
    radarFrameDwell: 2200,       // radar loop: dwell on the newest frame before looping
}