// Theme Colors
const COLORS = {
    textMain: '#f8fafc',
    textMuted: '#94a3b8',
    grid: 'rgba(255,255,255,0.1)',
    melee: '#f43f5e',
    ws: '#8b5cf6',
    spell: '#06b6d4',
    ranged: '#eab308',
    sc: '#f97316',
    healing: '#10b981',
    miss: '#64748b',
    hit: '#3b82f6'
};

// Player colors for line chart (generated dynamically)
const playerColors = [
    '#38bdf8', '#fbbf24', '#34d399', '#f472b6', '#a78bfa', '#fb923c', '#2dd4bf'
];

Chart.defaults.color = COLORS.textMuted;
Chart.defaults.font.family = "'Outfit', sans-serif";

let dpsChart, breakdownChart, accuracyChart, evasionChart, damageTakenChart, healingChart;

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

function initDashboard() {
    // If parseData doesn't exist yet, default to empty
    const data = typeof parseData !== 'undefined' ? parseData : [];

    if (data.length === 0) {
        console.warn("No parse data found. Trigger an export in FFXI first.");
    }

    processData(data);
}

function processData(data) {
    let totalDmg = 0;
    let totalHeal = 0;
    let totalWsDmg = 0;
    let totalWsCount = 0;
    let hits = 0;
    let misses = 0;

    const players = new Set();
    const timelineMap = new Map(); // timestamp (rounded to 10s) -> { player: damage }
    const breakdownMap = new Map(); // player -> { melee, ws, spell, sc, ranged }
    const defMap = new Map(); // player -> { hitsTaken: 0, missesEvaded: 0, dmgTaken: 0 }
    const healMap = new Map(); // player -> { amount: 0 }
    const accMap = new Map(); // player -> { hits: 0, misses: 0 }

    // Aggregate Data
    data.forEach(event => {
        const p = event.actor;
        
        // Use target for defensive events since actor is the mob
        const target = event.target;
        
        // Initialize maps
        if (event.type !== 'defense') players.add(p);
        else players.add(target);

        if (!breakdownMap.has(p)) breakdownMap.set(p, { melee: 0, ws: 0, spell: 0, sc: 0, ranged: 0 });
        if (!healMap.has(p)) healMap.set(p, { amount: 0 });
        if (!accMap.has(p)) accMap.set(p, { hits: 0, misses: 0 });
        if (!defMap.has(target)) defMap.set(target, { hitsTaken: 0, missesEvaded: 0, dmgTaken: 0 });

        // Stats
        if (event.type === 'healing') {
            totalHeal += event.value;
            healMap.get(p).amount += event.value;
        } else if (event.type === 'defense') {
            // Defense events: actor = mob, target = player
            if (event.hit) {
                defMap.get(target).hitsTaken++;
                defMap.get(target).dmgTaken += event.value;
            } else {
                defMap.get(target).missesEvaded++;
            }
        } else {
            totalDmg += event.value;
            if (event.type === 'skillchain') {
                breakdownMap.get(p).sc += event.value;
            } else if (event.type === 'offense') {
                if (event.hit) accMap.get(p).hits++; else accMap.get(p).misses++;
                
                // Categorize
                const d = event.detail;
                if (d.includes('melee') || d.includes('crit')) breakdownMap.get(p).melee += event.value;
                else if (d.includes('ws')) {
                    breakdownMap.get(p).ws += event.value;
                    totalWsDmg += event.value;
                    totalWsCount++;
                }
                else if (d.includes('spell') || d.includes('mb')) breakdownMap.get(p).spell += event.value;
                else if (d.includes('ranged')) breakdownMap.get(p).ranged += event.value;
            }
        }

        // Timeline (group by 10s intervals)
        if (event.type === 'offense' || event.type === 'skillchain') {
            const bucket = Math.floor(event.timestamp / 10) * 10;
            if (!timelineMap.has(bucket)) timelineMap.set(bucket, {});
            if (!timelineMap.get(bucket)[p]) timelineMap.get(bucket)[p] = 0;
            timelineMap.get(bucket)[p] += event.value;
        }
    });

    // Update Top Cards
    document.getElementById('total-damage').textContent = formatNumber(totalDmg);
    document.getElementById('total-healing').textContent = formatNumber(totalHeal);
    
    let wsAvg = totalWsCount > 0 ? Math.floor(totalWsDmg / totalWsCount) : 0;
    document.getElementById('ws-average').textContent = formatNumber(wsAvg);

    renderDpsChart(timelineMap, Array.from(players));
    renderBreakdownChart(breakdownMap, Array.from(players));
    renderAccuracyChart(accMap, Array.from(players));
    renderEvasionChart(defMap, Array.from(players));
    renderDamageTakenChart(defMap, Array.from(players));
    renderHealingChart(healMap, Array.from(players));
}

function renderDpsChart(timelineMap, players) {
    const ctx = document.getElementById('dpsChart').getContext('2d');
    
    // Sort time buckets
    const times = Array.from(timelineMap.keys()).sort();
    
    const datasets = players.map((p, i) => {
        const pColor = playerColors[i % playerColors.length];
        return {
            label: p,
            data: times.map(t => timelineMap.get(t)[p] || 0),
            borderColor: pColor,
            backgroundColor: pColor + '40', // 25% opacity
            fill: true,
            tension: 0.4
        };
    });

    // Format labels as MM:SS
    const labels = times.map(t => {
        const d = new Date(t * 1000);
        return d.getMinutes().toString().padStart(2, '0') + ':' + d.getSeconds().toString().padStart(2, '0');
    });

    if (dpsChart) dpsChart.destroy();

    dpsChart = new Chart(ctx, {
        type: 'line',
        data: { labels, datasets },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: { mode: 'index', intersect: false },
            scales: {
                x: { grid: { color: COLORS.grid } },
                y: { grid: { color: COLORS.grid }, beginAtZero: true }
            },
            plugins: {
                legend: { labels: { color: COLORS.textMain } }
            }
        }
    });
}

function renderBreakdownChart(breakdownMap, players) {
    const ctx = document.getElementById('breakdownChart').getContext('2d');
    
    const datasets = [
        { label: 'Melee', backgroundColor: COLORS.melee, data: players.map(p => breakdownMap.get(p) ? breakdownMap.get(p).melee : 0) },
        { label: 'Weaponskill', backgroundColor: COLORS.ws, data: players.map(p => breakdownMap.get(p) ? breakdownMap.get(p).ws : 0) },
        { label: 'Magic', backgroundColor: COLORS.spell, data: players.map(p => breakdownMap.get(p) ? breakdownMap.get(p).spell : 0) },
        { label: 'Skillchain', backgroundColor: COLORS.sc, data: players.map(p => breakdownMap.get(p) ? breakdownMap.get(p).sc : 0) },
        { label: 'Ranged', backgroundColor: COLORS.ranged, data: players.map(p => breakdownMap.get(p) ? breakdownMap.get(p).ranged : 0) }
    ];

    if (breakdownChart) breakdownChart.destroy();

    breakdownChart = new Chart(ctx, {
        type: 'bar',
        data: { labels: players, datasets },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: { stacked: true, grid: { display: false }, ticks: { color: COLORS.textMuted } },
                y: { stacked: true, grid: { color: COLORS.grid }, ticks: { color: COLORS.textMuted } }
            },
            plugins: {
                legend: { position: 'bottom', labels: { color: COLORS.textMain } }
            }
        }
    });
}

function renderAccuracyChart(accMap, players) {
    const ctx = document.getElementById('accuracyChart').getContext('2d');
    
    const datasets = [
        { label: 'Hits', backgroundColor: COLORS.hit, data: players.map(p => accMap.get(p) ? accMap.get(p).hits : 0) },
        { label: 'Misses', backgroundColor: COLORS.miss, data: players.map(p => accMap.get(p) ? accMap.get(p).misses : 0) }
    ];

    if (accuracyChart) accuracyChart.destroy();

    accuracyChart = new Chart(ctx, {
        type: 'bar',
        data: { labels: players, datasets },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: { stacked: true, grid: { display: false }, ticks: { color: COLORS.textMuted } },
                y: { stacked: true, grid: { color: COLORS.grid }, ticks: { color: COLORS.textMuted } }
            },
            plugins: {
                legend: { position: 'bottom', labels: { color: COLORS.textMain } }
            }
        }
    });
}

function renderEvasionChart(defMap, players) {
    const ctx = document.getElementById('evasionChart').getContext('2d');
    
    const datasets = [
        { label: 'Evaded', backgroundColor: COLORS.healing, data: players.map(p => defMap.get(p) ? defMap.get(p).missesEvaded : 0) },
        { label: 'Taken', backgroundColor: COLORS.melee, data: players.map(p => defMap.get(p) ? defMap.get(p).hitsTaken : 0) }
    ];

    if (evasionChart) evasionChart.destroy();

    evasionChart = new Chart(ctx, {
        type: 'bar',
        data: { labels: players, datasets },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: { stacked: true, grid: { display: false }, ticks: { color: COLORS.textMuted } },
                y: { stacked: true, grid: { color: COLORS.grid }, ticks: { color: COLORS.textMuted } }
            },
            plugins: {
                legend: { position: 'bottom', labels: { color: COLORS.textMain } }
            }
        }
    });
}

function renderDamageTakenChart(defMap, players) {
    const ctx = document.getElementById('damageTakenChart').getContext('2d');
    
    const datasets = [
        { label: 'Damage Taken', backgroundColor: COLORS.melee, data: players.map(p => defMap.get(p) ? defMap.get(p).dmgTaken : 0) }
    ];

    if (damageTakenChart) damageTakenChart.destroy();

    damageTakenChart = new Chart(ctx, {
        type: 'bar',
        data: { labels: players, datasets },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: { grid: { display: false }, ticks: { color: COLORS.textMuted } },
                y: { grid: { color: COLORS.grid }, ticks: { color: COLORS.textMuted } }
            },
            plugins: {
                legend: { position: 'bottom', labels: { color: COLORS.textMain } }
            }
        }
    });
}

function renderHealingChart(healMap, players) {
    const ctx = document.getElementById('healingChart').getContext('2d');
    
    const datasets = [
        { label: 'Healing Done', backgroundColor: COLORS.healing, data: players.map(p => healMap.get(p) ? healMap.get(p).amount : 0) }
    ];

    if (healingChart) healingChart.destroy();

    healingChart = new Chart(ctx, {
        type: 'bar',
        data: { labels: players, datasets },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: { grid: { display: false }, ticks: { color: COLORS.textMuted } },
                y: { grid: { color: COLORS.grid }, ticks: { color: COLORS.textMuted } }
            },
            plugins: {
                legend: { position: 'bottom', labels: { color: COLORS.textMain } }
            }
        }
    });
}

// Allow manual refresh by reloading the page
document.getElementById('refresh-btn').addEventListener('click', () => {
    window.location.reload();
});

// Init on load
document.addEventListener('DOMContentLoaded', initDashboard);
