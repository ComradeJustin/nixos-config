// ── Clock ──
function updateClock() {
  const now = new Date();
  const h = now.getHours().toString().padStart(2, '0');
  const m = now.getMinutes().toString().padStart(2, '0');
  document.getElementById('time').textContent = `${h}:${m}`;

  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const months = ['January', 'February', 'March', 'April', 'May', 'June',
                   'July', 'August', 'September', 'October', 'November', 'December'];
  const day = days[now.getDay()];
  const month = months[now.getMonth()];
  const date = now.getDate();
  document.getElementById('date').textContent = `${day}, ${month} ${date}`;
}

updateClock();
setInterval(updateClock, 1000);

// ── Greeting ──
function updateGreeting() {
  const hour = new Date().getHours();
  let greeting;
  if (hour < 6) greeting = 'Late night?';
  else if (hour < 12) greeting = 'Good morning';
  else if (hour < 17) greeting = 'Good afternoon';
  else if (hour < 21) greeting = 'Good evening';
  else greeting = 'Good night';
  document.getElementById('greeting').textContent = greeting;
}

updateGreeting();
setInterval(updateGreeting, 60000);

// ── Search ──
document.getElementById('searchForm').addEventListener('submit', function(e) {
  const q = document.getElementById('searchInput').value.trim();
  if (!q) {
    e.preventDefault();
    return;
  }
  // Direct URL detection
  if (q.match(/^https?:\/\//) || q.match(/^[\w-]+\.\w{2,}/)) {
    e.preventDefault();
    window.location.href = q.startsWith('http') ? q : 'https://' + q;
  }
});
