// ── Topology background ──
(function () {
    const canvas = document.getElementById('topo-bg');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');

    const NODE_COUNT = 100;
    const CONNECT_DIST = 200;
    const NODE_RADIUS = 2;
    const SPEED = 0.2;

    let w, h, nodes;

    function resize() {
        w = canvas.width = window.innerWidth;
        h = canvas.height = window.innerHeight;
    }

    function init() {
        resize();
        nodes = [];
        for (let i = 0; i < NODE_COUNT; i++) {
            nodes.push({
                x: Math.random() * w,
                y: Math.random() * h,
                vx: (Math.random() - 0.5) * SPEED,
                vy: (Math.random() - 0.5) * SPEED,
            });
        }
    }

    function draw() {
        ctx.clearRect(0, 0, w, h);

        // Draw connections
        for (let i = 0; i < nodes.length; i++) {
            for (let j = i + 1; j < nodes.length; j++) {
                const dx = nodes[i].x - nodes[j].x;
                const dy = nodes[i].y - nodes[j].y;
                const dist = Math.sqrt(dx * dx + dy * dy);
                if (dist < CONNECT_DIST) {
                    const alpha = (1 - dist / CONNECT_DIST) * 0.25;
                    ctx.beginPath();
                    ctx.moveTo(nodes[i].x, nodes[i].y);
                    ctx.lineTo(nodes[j].x, nodes[j].y);
                    ctx.strokeStyle = 'rgba(89, 207, 255, ' + alpha + ')';
                    ctx.lineWidth = 0.8;
                    ctx.stroke();
                }
            }
        }

        // Draw nodes
        for (const n of nodes) {
            ctx.beginPath();
            ctx.arc(n.x, n.y, NODE_RADIUS, 0, Math.PI * 2);
            ctx.fillStyle = 'rgba(89, 207, 255, 0.5)';
            ctx.fill();
        }

        // Update positions
        for (const n of nodes) {
            n.x += n.vx;
            n.y += n.vy;
            if (n.x < 0 || n.x > w) n.vx *= -1;
            if (n.y < 0 || n.y > h) n.vy *= -1;
        }

        requestAnimationFrame(draw);
    }

    init();
    draw();
    window.addEventListener('resize', resize);
})();


// ── Boot sequence ──
(function () {
    const bootEl = document.getElementById('boot');
    const logEl = document.getElementById('boot-log');
    const skipEl = document.getElementById('boot-skip');
    const siteEl = document.getElementById('site');

    if (!bootEl || !logEl) {
        // No boot screen on this page
        if (siteEl) siteEl.style.display = '';
        return;
    }

    // Skip if already seen this session
    if (sessionStorage.getItem('boot-done')) {
        bootEl.classList.add('hidden');
        siteEl.style.display = '';
        return;
    }

    const lines = [
        { text: "BIOS v1.04 — POST OK", cls: "dim", delay: 35 },
        { text: "Memory: 8192 MB ... checked", cls: "dim", delay: 25 },
        { text: "Network Nodes: 2 ... checked", cls: "dim", delay: 25 },
        { text: "", delay: 0 },
        { text: "Loading Nixos Configuration ...", cls: "info", delay: 30 },
        { text: "[  OK  ] Started Network Manager", cls: "ok", delay: 25 },
        //{ text: "[  OK  ] Started Tailscale daemon", cls: "ok", delay: 25 },
        //{ text: "[  OK  ] Started nginx", cls: "ok", delay: 25 },
        { text: "[ WARN ] Harmonia cache: 2 packages stale", cls: "warn", delay: 30 },
        { text: "[  OK  ] Started Remote Builder", cls: "ok", delay: 25 },
        { text: "[ WARN ] Opened Port on: 443", cls: "warn", delay: 30 },
        //{ text: "[  OK  ] Started AdGuard Home", cls: "ok", delay: 25 },
        //{ text: "[  OK  ] Started Grafana", cls: "ok", delay: 25 },
        { text: "", delay: 0 },
        { text: "All services nominal.", cls: "info", delay: 30 },
        { text: "", delay: 0 },
        { text: "login: guest", cls: "", delay: 40 },
        { text: "password: ********", cls: "", delay: 30 },
        { text: "", delay: 0 },
        { text: "Access granted.", cls: "ok", delay: 0 },
    ];

    let lineIdx = 0;
    let charIdx = 0;
    let currentSpan = null;
    let interrupted = false;
    const cursorSpan = document.createElement('span');
    cursorSpan.className = 'boot-cursor';
    cursorSpan.textContent = '\u2588';

    function finishBoot() {
        sessionStorage.setItem('boot-done', '1');
        bootEl.style.transition = 'opacity 0.3s ease';
        bootEl.style.opacity = '0';
        setTimeout(() => {
            bootEl.classList.add('hidden');
            siteEl.style.display = '';
        }, 300);
    }

    function interrupt() {
        if (interrupted) return;
        interrupted = true;
        cursorSpan.remove();
        const br = document.createElement('br');
        logEl.appendChild(br);
        const ctrl = document.createElement('span');
        ctrl.className = 'boot-interrupted';
        ctrl.textContent = '^C';
        logEl.appendChild(ctrl);
        skipEl.style.display = 'none';
        setTimeout(finishBoot, 600);
    }

    function typeLine() {
        if (interrupted) return;
        if (lineIdx >= lines.length) {
            cursorSpan.remove();
            setTimeout(finishBoot, 600);
            return;
        }

        const line = lines[lineIdx];

        // Empty line = just a newline
        if (line.text === "") {
            logEl.appendChild(document.createElement('br'));
            lineIdx++;
            setTimeout(typeLine, 150);
            return;
        }

        // Create span for this line
        currentSpan = document.createElement('span');
        if (line.cls) currentSpan.className = line.cls;
        logEl.appendChild(currentSpan);

        charIdx = 0;
        typeChar(line);
    }

    function typeChar(line) {
        if (interrupted) return;
        if (charIdx >= line.text.length) {
            // Line done
            logEl.appendChild(document.createElement('br'));
            cursorSpan.remove();
            lineIdx++;
            charIdx = 0;
            setTimeout(typeLine, 200);
            return;
        }

        currentSpan.textContent = line.text.substring(0, charIdx + 1);
        // Keep cursor at end
        currentSpan.after(cursorSpan);
        charIdx++;
        setTimeout(() => typeChar(line), line.delay || 40);
    }

    // Start
    typeLine();

    // Skip handler
    document.addEventListener('keydown', function handler(e) {
        interrupt();
        document.removeEventListener('keydown', handler);
    });
    bootEl.addEventListener('click', interrupt);
})();


// ── Cursor blink on nav prompt ──
(function () {
    const prompt = document.querySelector('.nav-prompt');
    if (prompt) {
        let visible = true;
        setInterval(() => {
            visible = !visible;
            prompt.textContent = visible
                ? 'guest@justin:~$ _'
                : 'guest@justin:~$  ';
        }, 530);
    }
})();


// ── Fade in sections on scroll ──
(function () {
    const sections = document.querySelectorAll('section, .project-card');
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
            }
        });
    }, { threshold: 0.1 });

    sections.forEach((s, i) => {
        s.classList.add('fade-in');
        s.style.transitionDelay = (i * 0.05) + 's';
        observer.observe(s);
    });

    const style = document.createElement('style');
    style.textContent = `
    .fade-in {
      opacity: 0;
      transform: translateY(8px);
      transition: opacity 0.4s ease, transform 0.4s ease;
    }
    .fade-in.visible {
      opacity: 1;
      transform: translateY(0);
    }
  `;
    document.head.appendChild(style);
})();


// ── Glitch effect on name hover ──
(function () {
    const ascii = document.querySelector('.ascii-name');
    if (!ascii) return;
    const original = ascii.textContent;
    const chars = '!@#$%^&*()_+-=[]{}|;:,.<>?/~`01';

    ascii.addEventListener('mouseenter', () => {
        let iterations = 0;
        const interval = setInterval(() => {
            ascii.textContent = original
                .split('')
                .map((ch, i) => {
                    if (ch === ' ' || ch === '\n') return ch;
                    if (i < iterations * 2) return original[i];
                    return chars[Math.floor(Math.random() * chars.length)];
                })
                .join('');
            iterations++;
            if (iterations > original.length / 2) {
                ascii.textContent = original;
                clearInterval(interval);
            }
        }, 25);
    });
})();


// ── Network status panel ──
(function () {
    const panel = document.getElementById('status-panel');
    if (!panel) return;

    const dot = document.getElementById('status-dot');
    const body = document.getElementById('status-body');

    // Friendly display names for systemd services
    const svcNames = {
        'nginx': 'nginx',
        'tailscaled': 'tailscale',
        'harmonia': 'harmonia',
        'nix-daemon': 'builder',
        'grafana': 'grafana',
        'adguardhome': 'adguard',
        'jellyfin': 'jellyfin',
        'radarr': 'radarr',
        'sonarr': 'sonarr',
    };

    function render(data) {
        let html = '';

        // System stats
        html += row('host', data.hostname || '--', 'dim');
        html += row('uptime', data.uptime || '--', 'dim');
        html += row('load', data.load || '--', 'dim');
        html += row('memory', data.memory || '--', 'dim');
        html += row('disk', data.disk || '--', 'dim');
        html += '<div class="status-sep"></div>';

        // Services
        const svcs = data.services || {};
        for (const [svc, active] of Object.entries(svcs)) {
            const name = svcNames[svc] || svc;
            const cls = active ? 'up' : 'down';
            const text = active ? 'up' : 'down';
            html += row(name, text, cls);
        }

        html += '<div class="status-sep"></div>';
        html += row('nodes', (data.nodes || 0) + ' online', 'dim');
        html += row('gen', '#' + (data.generation || '--'), 'dim');

        // Updated time
        if (data.timestamp) {
            const d = new Date(data.timestamp * 1000);
            const hh = String(d.getHours()).padStart(2, '0');
            const mm = String(d.getMinutes()).padStart(2, '0');
            html += row('updated', hh + ':' + mm, 'dim');
        }

        body.innerHTML = html;

        // Overall dot
        const allUp = Object.values(svcs).every(v => v);
        dot.className = 'status-dot ' + (allUp ? 'online' : 'offline');
    }

    function row(label, value, cls) {
        return '<div class="status-row">' +
            '<span class="status-label">' + label + '</span>' +
            '<span class="status-value ' + (cls || '') + '">' + value + '</span>' +
            '</div>';
    }

    function fetchStatus() {
        fetch('/api/status.json')
            .then(r => r.json())
            .then(render)
            .catch(() => {
                dot.className = 'status-dot offline';
            });
    }

    fetchStatus();
    setInterval(fetchStatus, 30000);
})();
