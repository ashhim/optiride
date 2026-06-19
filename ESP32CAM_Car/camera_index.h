#pragma once

// Minimal fullscreen desktop UI with keyboard control and zero on-screen buttons
static const char index_html[] = R"rawliteral(
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
  <meta name="theme-color" content="#000000">
  <title>ESP32 CAM Car</title>
  <style>
    :root{
      color-scheme: dark;
      --bg: #000;
      --glass: rgba(12, 14, 20, .52);
      --line: rgba(255,255,255,.08);
      --text: rgba(245,248,255,.96);
      --muted: rgba(245,248,255,.66);
      --accent: #7ee0ff;
      --good: #74f2a8;
      --warn: #ffda73;
    }
    html,body{
      margin:0;
      width:100%;
      height:100%;
      overflow:hidden;
      background:var(--bg);
      font-family: Inter, system-ui, -apple-system, "Segoe UI", Arial, sans-serif;
      cursor:none;
      user-select:none;
      -webkit-user-select:none;
      -webkit-tap-highlight-color: transparent;
    }
    #stage{
      position:fixed;
      inset:0;
      background:#000;
    }
    #stream{
      position:absolute;
      inset:0;
      width:100vw;
      height:100vh;
      object-fit:contain;
      background:#000;
      transform:translateZ(0);
      user-drag:none;
      -webkit-user-drag:none;
      pointer-events:none;
    }
    #overlay{
      position:fixed;
      top:16px;
      left:16px;
      z-index:5;
      display:flex;
      gap:10px;
      align-items:flex-start;
      pointer-events:none;
    }
    .panel{
      background:var(--glass);
      border:1px solid var(--line);
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
      border-radius:16px;
      padding:12px 14px;
      box-shadow:0 20px 60px rgba(0,0,0,.38);
    }
    .brand{
      font-size:14px;
      font-weight:700;
      letter-spacing:.2px;
      color:var(--text);
      margin-bottom:8px;
    }
    .chips{
      display:flex;
      flex-wrap:wrap;
      gap:8px;
    }
    .chip{
      display:inline-flex;
      align-items:center;
      gap:6px;
      padding:7px 10px;
      border-radius:999px;
      background:rgba(255,255,255,.06);
      border:1px solid rgba(255,255,255,.08);
      color:var(--muted);
      font-size:12px;
      line-height:1;
      white-space:nowrap;
    }
    .chip b{
      color:var(--text);
      font-weight:700;
    }
    .chip i{
      width:8px;
      height:8px;
      border-radius:999px;
      background:var(--good);
      display:inline-block;
      box-shadow:0 0 14px rgba(116,242,168,.45);
    }
    .chip.warn i{ background:var(--warn); box-shadow:0 0 14px rgba(255,218,115,.4); }
    .chip.accent i{ background:var(--accent); box-shadow:0 0 14px rgba(126,224,255,.4); }
    #toast{
      position:fixed;
      right:16px;
      bottom:16px;
      z-index:6;
      padding:10px 12px;
      border-radius:14px;
      background:var(--glass);
      border:1px solid var(--line);
      color:var(--text);
      font-size:12px;
      letter-spacing:.2px;
      box-shadow:0 20px 60px rgba(0,0,0,.38);
      opacity:0;
      transform:translateY(6px);
      transition:opacity .16s ease, transform .16s ease;
      pointer-events:none;
    }
    #toast.show{
      opacity:1;
      transform:translateY(0);
    }
    @media (max-width: 900px){
      #overlay{ top:12px; left:12px; right:12px; }
      .panel{ padding:10px 12px; border-radius:14px; }
    }
  </style>
</head>
<body tabindex="0">
  <div id="stage">
    <img id="stream" alt="Live stream">
  </div>

  <div id="overlay">
    <div class="panel">
      <div class="brand">ESP32 CAM Car</div>
      <div class="chips">
        <span class="chip accent"><i></i>Drive <b id="driveState">Idle</b></span>
        <span class="chip"><i></i>Steer <b id="steerState">Center</b></span>
        <span class="chip warn"><i></i>Light <b id="lightState">Off</b></span>
      </div>
    </div>
  </div>

  <div id="toast">Ready</div>

  <script>
    (() => {
      const base = `${location.protocol}//${location.hostname}`;
      const stream = document.getElementById('stream');
      const toast = document.getElementById('toast');
      const driveState = document.getElementById('driveState');
      const steerState = document.getElementById('steerState');
      const lightState = document.getElementById('lightState');

      const state = {
        drive: 'idle',
        steer: 'center',
        light: false,
        keys: { forward: false, backward: false, left: false, right: false },
        reconnectTimer: null,
        pingTimer: null,
      };

      function showToast(text) {
        toast.textContent = text;
        toast.classList.add('show');
        clearTimeout(showToast._t);
        showToast._t = setTimeout(() => toast.classList.remove('show'), 900);
      }

      function updateUI() {
        driveState.textContent = state.drive === 'forward' ? 'Forward' : state.drive === 'backward' ? 'Backward' : 'Idle';
        steerState.textContent = state.steer === 'left' ? 'Left' : state.steer === 'right' ? 'Right' : 'Center';
        lightState.textContent = state.light ? 'On' : 'Off';
      }

      async function send(path) {
        try {
          await fetch(`${base}${path}?t=${Date.now()}`, {
            method: 'GET',
            cache: 'no-store',
            credentials: 'same-origin'
          });
        } catch (_) {}
      }

      function setDrive(next) {
        if (state.drive === next) return;
        state.drive = next;
        if (next === 'forward') send('/forward');
        else if (next === 'backward') send('/backward');
        else send('/stopdrive');
        updateUI();
      }

      function setSteer(next) {
        if (state.steer === next) return;
        state.steer = next;
        if (next === 'left') send('/steerleft');
        else if (next === 'right') send('/steerright');
        else send('/stopsteer');
        updateUI();
      }

      function stopAll() {
        state.keys.forward = false;
        state.keys.backward = false;
        state.keys.left = false;
        state.keys.right = false;
        state.drive = 'idle';
        state.steer = 'center';
        send('/stopall');
        updateUI();
      }

      function toggleLight() {
        state.light = !state.light;
        send(state.light ? '/lighton' : '/lightoff');
        updateUI();
      }

      function connectStream() {
        stream.src = `${base}:81/stream?t=${Date.now()}`;
      }

      function refreshMotionFromKeys() {
        if (state.keys.forward && !state.keys.backward) setDrive('forward');
        else if (state.keys.backward && !state.keys.forward) setDrive('backward');
        else setDrive('idle');

        if (state.keys.left && !state.keys.right) setSteer('left');
        else if (state.keys.right && !state.keys.left) setSteer('right');
        else setSteer('center');
      }

      const keyMap = {
        w: 'forward',
        arrowup: 'forward',
        s: 'backward',
        arrowdown: 'backward',
        a: 'left',
        arrowleft: 'left',
        d: 'right',
        arrowright: 'right'
      };

      document.addEventListener('keydown', (e) => {
        const key = e.key.toLowerCase();

        if (key === ' ' || key === 'spacebar') {
          e.preventDefault();
          stopAll();
          showToast('Stopped');
          return;
        }

        if (key === 'l') {
          e.preventDefault();
          if (!e.repeat) {
            toggleLight();
            showToast(state.light ? 'Light on' : 'Light off');
          }
          return;
        }

        const action = keyMap[key];
        if (!action) return;

        e.preventDefault();
        if (e.repeat) return;

        state.keys[action] = true;
        refreshMotionFromKeys();
      });

      document.addEventListener('keyup', (e) => {
        const key = e.key.toLowerCase();
        const action = keyMap[key];
        if (!action) return;

        e.preventDefault();
        state.keys[action] = false;
        refreshMotionFromKeys();
      });

      window.addEventListener('blur', stopAll);
      window.addEventListener('pagehide', stopAll);
      document.addEventListener('visibilitychange', () => {
        if (document.hidden) stopAll();
      });

      document.addEventListener('DOMContentLoaded', () => document.body.focus());
      document.addEventListener('pointerdown', () => document.body.focus());

      stream.addEventListener('error', () => {
        showToast('Reconnecting');
        clearTimeout(state.reconnectTimer);
        state.reconnectTimer = setTimeout(connectStream, 700);
      });

      connectStream();
      updateUI();
      state.pingTimer = setInterval(() => {
        fetch(`${base}/ping?t=${Date.now()}`, { cache: 'no-store', credentials: 'same-origin' }).catch(() => {});
      }, 4000);

      showToast('Ready');
    })();
  </script>
</body>
</html>
)rawliteral";
