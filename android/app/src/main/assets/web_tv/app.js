/**
 * TV Atlas // 10-Foot Smart TV & Google TV Client
 * Full D-Pad Remote Navigation, HLS.js Live Streaming, Google Cast Support,
 * and Local LAN Synchronization.
 */

(function () {
  'use strict';

  // Application State
  const state = {
    channels: [],
    priorityChannels: [],
    currentChannel: null,
    activeCategory: 'all',
    searchQuery: '',
    favorites: JSON.parse(localStorage.getItem('tv_atlas_favorites') || '[]'),
    isPlaying: false,
    isFullscreen: false,
    hls: null,
    lanIp: '127.0.0.1',
    port: 8080,
    serverUrl: ''
  };

  // DOM Elements
  const el = {
    categoryNav: document.getElementById('categoryNav'),
    searchInput: document.getElementById('searchInput'),
    searchClear: document.getElementById('searchClear'),
    btnCast: document.getElementById('btnCast'),
    btnHelp: document.getElementById('btnHelp'),
    videoWrapper: document.getElementById('videoWrapper'),
    videoPlayer: document.getElementById('videoPlayer'),
    playerOverlay: document.getElementById('playerOverlay'),
    telemetryBar: document.getElementById('telemetryBar'),
    channelNameDisplay: document.getElementById('channelNameDisplay'),
    channelMetaDisplay: document.getElementById('channelMetaDisplay'),
    streamResBadge: document.getElementById('streamResBadge'),
    streamStatusBadge: document.getElementById('streamStatusBadge'),
    btnPlayPause: document.getElementById('btnPlayPause'),
    btnMute: document.getElementById('btnMute'),
    btnNext: document.getElementById('btnNext'),
    btnFavCurrent: document.getElementById('btnFavCurrent'),
    btnFullscreen: document.getElementById('btnFullscreen'),
    statusStripText: document.getElementById('statusStripText'),
    stationCountBadge: document.getElementById('stationCountBadge'),
    sectionTitle: document.getElementById('sectionTitle'),
    channelGrid: document.getElementById('channelGrid'),
    remoteModal: document.getElementById('remoteModal'),
    btnCloseModal: document.getElementById('btnCloseModal'),
    btnDismissModal: document.getElementById('btnDismissModal'),
    modalLanUrl: document.getElementById('modalLanUrl')
  };

  // ==========================================
  // 1. INITIALIZATION & DATA FETCHING
  // ==========================================
  async function init() {
    setupEventListeners();
    setupRemoteKeyNavigation();
    setupGoogleCast();

    try {
      // 1. Fetch Server Info
      const infoRes = await fetch('/api/info');
      if (infoRes.ok) {
        const info = await infoRes.json();
        state.lanIp = info.lan_ip || '127.0.0.1';
        state.port = info.port || 8080;
        state.serverUrl = info.tv_url || `http://${state.lanIp}:${state.port}`;
        el.modalLanUrl.textContent = state.serverUrl;
      }
    } catch (e) {
      console.warn('Local info fetch error:', e);
    }

    // 2. Fetch Priority Channels
    try {
      let prioRes = await fetch('/api/priority');
      if (!prioRes.ok) {
        prioRes = await fetch('priority_streams.json');
      }
      if (prioRes.ok) {
        state.priorityChannels = await prioRes.json();
      }
    } catch (e) {
      try {
        const localRes = await fetch('priority_streams.json');
        if (localRes.ok) state.priorityChannels = await localRes.json();
      } catch (err) {
        console.warn('Priority channels error:', err);
      }
    }

    // 3. Load Channels Directory
    await loadChannels();
  }

  async function loadChannels() {
    el.channelGrid.innerHTML = `
      <div class="loading-state">
        <div class="spinner"></div>
        <span>SEARCHING SATELLITE DIRECTORY...</span>
      </div>
    `;

    if (state.activeCategory === 'favorites') {
      renderChannels(state.favorites);
      el.sectionTitle.textContent = `PINNED FAVORITES (${state.favorites.length})`;
      el.stationCountBadge.textContent = `[${state.favorites.length} PINNED]`;
      return;
    }

    try {
      let url = `/api/channels?limit=160`;
      if (state.activeCategory && state.activeCategory !== 'all') {
        url += `&category=${encodeURIComponent(state.activeCategory)}`;
      }
      if (state.searchQuery) {
        url += `&q=${encodeURIComponent(state.searchQuery)}`;
      }

      const res = await fetch(url);
      if (!res.ok) throw new Error('Network error');
      const data = await res.json();
      state.channels = data.channels || [];

      renderChannels(state.channels);
      el.sectionTitle.textContent = state.searchQuery 
        ? `SEARCH RESULTS FOR "${state.searchQuery.toUpperCase()}" (${data.total || state.channels.length})`
        : (state.activeCategory === 'all' ? 'FEATURED & VERIFIED BROADCASTS' : `${state.activeCategory.toUpperCase()} CHANNELS`);
      el.stationCountBadge.textContent = `[${data.total || state.channels.length} NODES]`;
    } catch (err) {
      console.error('Failed to load channels:', err);
      // Fallback to priority channels if API fails
      renderChannels(state.priorityChannels);
      el.stationCountBadge.textContent = `[${state.priorityChannels.length} OFFLINE NODES]`;
    }
  }

  // ==========================================
  // 2. CHANNEL RENDERING & CARDS
  // ==========================================
  function renderChannels(channelList) {
    if (!channelList || channelList.length === 0) {
      el.channelGrid.innerHTML = `
        <div class="empty-state">
          <p>// NO MATCHING CHANNELS FOUND</p>
          <span style="font-size:0.8rem; color:#64748b;">Try adjusting your category filter or search keywords</span>
        </div>
      `;
      return;
    }

    el.channelGrid.innerHTML = '';
    channelList.forEach((ch, index) => {
      const isFav = isFavorite(ch);
      const isActive = state.currentChannel && state.currentChannel.url === ch.url;

      const card = document.createElement('div');
      card.className = `channel-card ${isActive ? 'active-stream' : ''}`;
      card.tabIndex = 0; // Focusable for TV remotes
      card.dataset.index = index;
      card.dataset.url = ch.url;

      card.innerHTML = `
        <div class="card-top">
          <span class="card-title" title="${escapeHtml(ch.name || 'Station')}">${escapeHtml(ch.name || 'Station')}</span>
          <button class="card-star ${isFav ? 'active' : ''}" title="Star channel" tabindex="-1">
            ${isFav ? '★' : '☆'}
          </button>
        </div>
        <div class="card-bottom">
          <span class="card-country">${escapeHtml(ch.country || 'GLOBAL')}</span>
          <span class="card-category">${escapeHtml(ch.category || 'General')}</span>
          <span class="card-quality">${escapeHtml(ch.quality || 'HD')}</span>
        </div>
      `;

      // Click to Play
      card.addEventListener('click', (e) => {
        if (e.target.closest('.card-star')) {
          toggleFavorite(ch, card.querySelector('.card-star'));
          return;
        }
        playChannel(ch);
      });

      // Enter/OK to Play on Remote
      card.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.keyCode === 13 || e.keyCode === 23) {
          playChannel(ch);
          e.preventDefault();
        }
      });

      el.channelGrid.appendChild(card);
    });
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str).replace(/[&<>"']/g, m => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[m]));
  }

  // ==========================================
  // 3. HLS LIVE STREAMING ENGINE
  // ==========================================
  function playChannel(ch) {
    if (!ch || !ch.url) return;
    state.currentChannel = ch;

    // Highlight card
    document.querySelectorAll('.channel-card').forEach(c => {
      c.classList.toggle('active-stream', c.dataset.url === ch.url);
    });

    // Update Telemetry Header
    el.channelNameDisplay.textContent = ch.name || 'Station';
    el.channelMetaDisplay.textContent = `// ${ch.countryName || ch.country || 'GLOBAL'} · ${ch.category || 'Live'}`;
    el.streamResBadge.textContent = ch.quality || 'HD';
    el.streamStatusBadge.textContent = 'CONNECTING...';
    el.streamStatusBadge.style.color = 'var(--cyan-primary)';
    el.playerOverlay.classList.add('hidden');
    el.btnFavCurrent.textContent = isFavorite(ch) ? '★' : '☆';
    el.btnFavCurrent.style.color = isFavorite(ch) ? 'var(--green-matrix)' : 'var(--text-primary)';

    const streamUrl = ch.url;

    // Destroy existing HLS instance
    if (state.hls) {
      state.hls.destroy();
      state.hls = null;
    }

    // Check if HLS.js is supported (Google TV Chromium, Desktop, Android)
    if (window.Hls && Hls.isSupported()) {
      const hls = new Hls({
        enableWorker: true,
        lowLatencyMode: true,
        backBufferLength: 30,
        maxBufferLength: 20,
        maxMaxBufferLength: 40,
        liveSyncDurationCount: 3,
        liveMaxLatencyDurationCount: 8
      });

      state.hls = hls;
      hls.loadSource(streamUrl);
      hls.attachMedia(el.videoPlayer);

      hls.on(Hls.Events.MANIFEST_PARSED, (event, data) => {
        el.videoPlayer.play().catch(e => console.log('Autoplay deferred:', e));
        el.streamStatusBadge.textContent = 'LIVE';
        el.streamStatusBadge.style.color = 'var(--green-matrix)';
        state.isPlaying = true;
        el.btnPlayPause.textContent = '⏸';
      });

      hls.on(Hls.Events.LEVEL_SWITCHED, (event, data) => {
        const level = hls.levels[data.level];
        if (level && level.height) {
          el.streamResBadge.textContent = `${level.height}p`;
        }
      });

      hls.on(Hls.Events.ERROR, (event, data) => {
        if (data.fatal) {
          console.warn('[TVAtlas] Stream fatal error:', data.type);
          switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              // Try proxy route once if direct CORS failed
              if (!streamUrl.includes('/api/proxy')) {
                const proxyUrl = `/api/proxy?url=${encodeURIComponent(streamUrl)}`;
                console.log('[TVAtlas] Retrying via TV CORS proxy...');
                hls.loadSource(proxyUrl);
                return;
              }
              showStreamOfflineNotice('NETWORK FEED OFFLINE');
              break;
            case Hls.ErrorTypes.MEDIA_ERROR:
              hls.recoverMediaError();
              break;
            default:
              showStreamOfflineNotice('STREAM DECODE ERROR');
              hls.destroy();
              break;
          }
        }
      });
    } else if (el.videoPlayer.canPlayType('application/vnd.apple.mpegurl')) {
      // Native Apple / Safari / WebOS HLS support
      el.videoPlayer.src = streamUrl;
      el.videoPlayer.play().catch(e => console.log('Native playback wait:', e));
      el.streamStatusBadge.textContent = 'LIVE';
      state.isPlaying = true;
      el.btnPlayPause.textContent = '⏸';
    } else {
      showStreamOfflineNotice('HLS PLAYBACK NOT SUPPORTED');
    }

    // Scroll player into view if on mobile/smaller screens
    if (window.innerWidth < 1080) {
      el.playerSection.scrollIntoView({ behavior: 'smooth' });
    }
  }

  function showStreamOfflineNotice(reason) {
    el.streamStatusBadge.textContent = 'OFFLINE';
    el.streamStatusBadge.style.color = 'var(--red-accent)';
    el.channelMetaDisplay.textContent = `// ${reason} · RETRY OR SELECT ANOTHER`;
    state.isPlaying = false;
    el.btnPlayPause.textContent = '▶';
  }

  // ==========================================
  // 4. REMOTE CONTROL & D-PAD NAVIGATION
  // ==========================================
  function setupRemoteKeyNavigation() {
    window.addEventListener('keydown', (e) => {
      // Don't intercept when user is typing in search input
      if (document.activeElement === el.searchInput) {
        if (e.key === 'Escape' || e.keyCode === 27) {
          el.searchInput.blur();
          focusFirstChannel();
          e.preventDefault();
        }
        return;
      }

      const key = e.key;
      const code = e.keyCode;

      // 1. D-Pad Directional Navigation
      if (key === 'ArrowUp' || code === 38) {
        handleDpadUp(e);
      } else if (key === 'ArrowDown' || code === 40) {
        handleDpadDown(e);
      } else if (key === 'ArrowLeft' || code === 37) {
        handleDpadLeft(e);
      } else if (key === 'ArrowRight' || code === 39) {
        handleDpadRight(e);
      } 
      // 2. OK / Select Button
      else if (key === 'Enter' || code === 13 || code === 23) {
        if (document.activeElement && document.activeElement.click) {
          // Native click triggered
        }
      }
      // 3. Back / Exit Button (Google TV Remote Back, Samsung Tizen 10009, LG 461)
      else if (key === 'Escape' || code === 27 || code === 8 || code === 10009 || code === 461 || code === 10007) {
        handleRemoteBack(e);
      }
      // 4. Media Play / Pause
      else if (code === 179 || key === 'MediaPlayPause' || (key === ' ' && document.activeElement !== el.searchInput)) {
        togglePlayPause();
        e.preventDefault();
      }
      // 5. Cinema Fullscreen (F, F11, or TV Yellow button)
      else if (key === 'f' || key === 'F' || code === 122) {
        toggleFullscreen();
        e.preventDefault();
      }
      // 6. Help Guide (?)
      else if (key === '?') {
        toggleHelpModal();
        e.preventDefault();
      }
    });
  }

  function handleDpadDown(e) {
    const active = document.activeElement;
    if (active && active.classList.contains('nav-pill')) {
      // From category pills down to first channel card
      focusFirstChannel();
      e.preventDefault();
    } else if (active && active.classList.contains('channel-card')) {
      // Move to next card in grid (grid is multi-column)
      const cards = Array.from(document.querySelectorAll('.channel-card'));
      const idx = cards.indexOf(active);
      const cols = getGridColumnCount();
      const nextIdx = idx + cols;
      if (nextIdx < cards.length) {
        cards[nextIdx].focus();
        cards[nextIdx].scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        e.preventDefault();
      }
    }
  }

  function handleDpadUp(e) {
    const active = document.activeElement;
    if (active && active.classList.contains('channel-card')) {
      const cards = Array.from(document.querySelectorAll('.channel-card'));
      const idx = cards.indexOf(active);
      const cols = getGridColumnCount();
      const prevIdx = idx - cols;
      if (prevIdx >= 0) {
        cards[prevIdx].focus();
        cards[prevIdx].scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        e.preventDefault();
      } else {
        // Move focus up to active category pill
        const activePill = document.querySelector('.nav-pill.active') || document.querySelector('.nav-pill');
        if (activePill) activePill.focus();
        e.preventDefault();
      }
    }
  }

  function handleDpadRight(e) {
    const active = document.activeElement;
    if (active && active.classList.contains('nav-pill')) {
      const nextPill = active.nextElementSibling;
      if (nextPill && nextPill.classList.contains('nav-pill')) {
        nextPill.focus();
        e.preventDefault();
      }
    } else if (active && active.classList.contains('channel-card')) {
      const nextCard = active.nextElementSibling;
      if (nextCard && nextCard.classList.contains('channel-card')) {
        nextCard.focus();
        nextCard.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        e.preventDefault();
      }
    }
  }

  function handleDpadLeft(e) {
    const active = document.activeElement;
    if (active && active.classList.contains('nav-pill')) {
      const prevPill = active.previousElementSibling;
      if (prevPill && prevPill.classList.contains('nav-pill')) {
        prevPill.focus();
        e.preventDefault();
      }
    } else if (active && active.classList.contains('channel-card')) {
      const prevCard = active.previousElementSibling;
      if (prevCard && prevCard.classList.contains('channel-card')) {
        prevCard.focus();
        prevCard.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        e.preventDefault();
      }
    }
  }

  function handleRemoteBack(e) {
    if (el.remoteModal.style.display !== 'none') {
      toggleHelpModal();
      e.preventDefault();
      return;
    }
    if (state.isFullscreen) {
      toggleFullscreen();
      e.preventDefault();
      return;
    }
    focusFirstChannel();
  }

  function focusFirstChannel() {
    const first = document.querySelector('.channel-card');
    if (first) {
      first.focus();
      first.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    }
  }

  function getGridColumnCount() {
    const grid = el.channelGrid;
    if (!grid || !grid.children.length) return 1;
    const first = grid.children[0];
    const second = grid.children[1];
    if (!second) return 1;
    return Math.max(1, Math.round(grid.offsetWidth / first.offsetWidth));
  }

  // ==========================================
  // 5. PLAYER CONTROLS & FULLSCREEN
  // ==========================================
  function togglePlayPause() {
    if (el.videoPlayer.paused) {
      el.videoPlayer.play();
      el.btnPlayPause.textContent = '⏸';
      state.isPlaying = true;
    } else {
      el.videoPlayer.pause();
      el.btnPlayPause.textContent = '▶';
      state.isPlaying = false;
    }
  }

  function toggleMute() {
    el.videoPlayer.muted = !el.videoPlayer.muted;
    el.btnMute.textContent = el.videoPlayer.muted ? '🔇' : '🔊';
  }

  function playNextChannel() {
    if (!state.channels.length) return;
    const currentUrl = state.currentChannel ? state.currentChannel.url : null;
    let idx = state.channels.findIndex(c => c.url === currentUrl);
    let nextIdx = (idx + 1) % state.channels.length;
    playChannel(state.channels[nextIdx]);
  }

  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      if (el.videoWrapper.requestFullscreen) {
        el.videoWrapper.requestFullscreen();
      } else if (el.videoWrapper.webkitRequestFullscreen) {
        el.videoWrapper.webkitRequestFullscreen();
      }
      state.isFullscreen = true;
      el.btnFullscreen.textContent = '🗕';
    } else {
      if (document.exitFullscreen) {
        document.exitFullscreen();
      }
      state.isFullscreen = false;
      el.btnFullscreen.textContent = '⛶';
    }
  }

  document.addEventListener('fullscreenchange', () => {
    state.isFullscreen = !!document.fullscreenElement;
    el.btnFullscreen.textContent = state.isFullscreen ? '🗕' : '⛶';
  });

  // ==========================================
  // 6. FAVORITES HANDLING
  // ==========================================
  function isFavorite(ch) {
    if (!ch) return false;
    const key = ch.url || ch.id;
    return state.favorites.some(f => (f.url || f.id) === key);
  }

  function toggleFavorite(ch, starElement) {
    if (!ch) return;
    const key = ch.url || ch.id;
    const exists = state.favorites.findIndex(f => (f.url || f.id) === key);

    if (exists >= 0) {
      state.favorites.splice(exists, 1);
      if (starElement) {
        starElement.textContent = '☆';
        starElement.classList.remove('active');
      }
    } else {
      state.favorites.unshift(ch);
      if (starElement) {
        starElement.textContent = '★';
        starElement.classList.add('active');
      }
    }

    localStorage.setItem('tv_atlas_favorites', JSON.stringify(state.favorites));
    if (state.currentChannel && (state.currentChannel.url || state.currentChannel.id) === key) {
      el.btnFavCurrent.textContent = isFavorite(ch) ? '★' : '☆';
      el.btnFavCurrent.style.color = isFavorite(ch) ? 'var(--green-matrix)' : 'var(--text-primary)';
    }

    if (state.activeCategory === 'favorites') {
      renderChannels(state.favorites);
    }
  }

  // ==========================================
  // 7. GOOGLE CAST INTEGRATION
  // ==========================================
  function setupGoogleCast() {
    window['__onGCastApiAvailable'] = function (isAvailable) {
      if (isAvailable && window.cast && window.cast.framework) {
        cast.framework.CastContext.getInstance().setOptions({
          receiverApplicationId: chrome.cast.media.DEFAULT_MEDIA_RECEIVER_APP_ID,
          autoJoinPolicy: chrome.cast.AutoJoinPolicy.ORIGIN_SCOPED
        });
        el.btnCast.style.display = 'flex';
      }
    };

    el.btnCast.addEventListener('click', () => {
      if (window.cast && window.cast.framework) {
        cast.framework.CastContext.getInstance().requestSession().then(
          () => {
            const session = cast.framework.CastContext.getInstance().getCurrentSession();
            if (session && state.currentChannel) {
              const mediaInfo = new chrome.cast.media.MediaInfo(state.currentChannel.url, 'application/x-mpegURL');
              mediaInfo.metadata = new chrome.cast.media.GenericMediaMetadata();
              mediaInfo.metadata.title = state.currentChannel.name || 'TV Atlas Stream';
              const request = new chrome.cast.media.LoadRequest(mediaInfo);
              session.loadMedia(request);
            }
          },
          err => console.log('Cast request error:', err)
        );
      } else {
        alert('Google Cast is ready. Make sure your Google TV is on the same Wi-Fi network.');
      }
    });
  }

  // ==========================================
  // 8. EVENT LISTENERS
  // ==========================================
  function setupEventListeners() {
    // Category pills click
    el.categoryNav.addEventListener('click', (e) => {
      const btn = e.target.closest('.nav-pill');
      if (!btn) return;

      document.querySelectorAll('.nav-pill').forEach(p => p.classList.remove('active'));
      btn.classList.add('active');
      state.activeCategory = btn.dataset.category || 'all';
      loadChannels();
    });

    // Search input
    let searchDebounce;
    el.searchInput.addEventListener('input', (e) => {
      clearTimeout(searchDebounce);
      state.searchQuery = e.target.value.trim();
      el.searchClear.style.display = state.searchQuery ? 'block' : 'none';
      searchDebounce = setTimeout(() => {
        loadChannels();
      }, 350);
    });

    el.searchClear.addEventListener('click', () => {
      el.searchInput.value = '';
      state.searchQuery = '';
      el.searchClear.style.display = 'none';
      loadChannels();
      el.searchInput.focus();
    });

    // Player Buttons
    el.btnPlayPause.addEventListener('click', togglePlayPause);
    el.btnMute.addEventListener('click', toggleMute);
    el.btnNext.addEventListener('click', playNextChannel);
    el.btnFavCurrent.addEventListener('click', () => {
      if (state.currentChannel) {
        toggleFavorite(state.currentChannel, null);
      }
    });
    el.btnFullscreen.addEventListener('click', toggleFullscreen);

    // Help Modal
    el.btnHelp.addEventListener('click', toggleHelpModal);
    el.btnCloseModal.addEventListener('click', toggleHelpModal);
    el.btnDismissModal.addEventListener('click', toggleHelpModal);
  }

  function toggleHelpModal() {
    const isVisible = el.remoteModal.style.display !== 'none';
    el.remoteModal.style.display = isVisible ? 'none' : 'flex';
    if (!isVisible) {
      el.btnDismissModal.focus();
    } else {
      focusFirstChannel();
    }
  }

  // Launch on DOM ready
  document.addEventListener('DOMContentLoaded', init);
})();
