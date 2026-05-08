/**
 * 学榜记 Web 前端 - 主应用逻辑
 */

// ═══════════════════════════════════════════════════════
// 导航
// ═══════════════════════════════════════════════════════

let currentPage = 'splash';
let currentTab = 'home';
let pageHistory = [];

function navigateTo(page) {
  if (currentPage === 'main' && page !== 'main') {
    pageHistory.push('main');
  }
  showPage(page);
}

function goBack() {
  const prev = pageHistory.pop() || 'main';
  showPage(prev);
}

function showPage(page) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  const el = document.getElementById('page-' + page);
  if (el) el.classList.add('active');
  currentPage = page;

  if (page === 'main') {
    switchTab(currentTab);
  }
  if (page === 'login' || page === 'register') {
    loadTracks();
  }
  if (page === 'subjects') {
    loadSubjects();
  }
  if (page === 'notifications') {
    loadNotifications();
  }
  if (page === 'admin-ads') {
    loadAdminAds();
  }
}

function switchTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.tab-content').forEach(t => t.style.display = 'none');
  const el = document.getElementById('tab-' + tab);
  if (el) el.style.display = 'block';

  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  document.querySelector(`.nav-item[data-tab="${tab}"]`)?.classList.add('active');

  if (tab === 'home') refreshHome();
  if (tab === 'records') loadRecords();
  if (tab === 'leaderboard') loadLeaderboard();
  if (tab === 'profile') loadProfile();
}

// ═══════════════════════════════════════════════════════
// Toast
// ═══════════════════════════════════════════════════════

function showToast(msg, type = '') {
  const toast = document.getElementById('toast');
  toast.textContent = msg;
  toast.className = 'toast ' + type + ' show';
  clearTimeout(toast._timeout);
  toast._timeout = setTimeout(() => toast.classList.remove('show'), 2500);
}

// ═══════════════════════════════════════════════════════
// Modal
// ═══════════════════════════════════════════════════════

function showModal(html) {
  document.getElementById('modal-content').innerHTML = html;
  document.getElementById('modal-overlay').style.display = 'flex';
}

function closeModal(e) {
  if (e && e.target !== document.getElementById('modal-overlay')) return;
  document.getElementById('modal-overlay').style.display = 'none';
}

// ═══════════════════════════════════════════════════════
// Auth
// ═══════════════════════════════════════════════════════

async function loadTracks() {
  try {
    const resp = await api.getTracks();
    const tracks = resp.data;
    const select = document.getElementById('reg-track');
    if (select && select.options.length <= 1) {
      // Group by category
      const cats = {};
      tracks.forEach(t => {
        if (!cats[t.category]) cats[t.category] = [];
        cats[t.category].push(t);
      });
      for (const [cat, items] of Object.entries(cats)) {
        const optgroup = document.createElement('optgroup');
        optgroup.label = cat;
        items.forEach(item => {
          const opt = document.createElement('option');
          opt.value = item.id;
          opt.textContent = item.name;
          optgroup.appendChild(opt);
        });
        select.appendChild(optgroup);
      }
    }
  } catch (e) { /* ignore */ }
}

async function sendRegCode() {
  const phone = document.getElementById('reg-phone').value;
  if (!/^1[3-9]\d{9}$/.test(phone)) {
    showToast('手机号格式错误', 'error');
    return;
  }
  try {
    await api.sendSms(phone, 'register');
    showToast('验证码已发送（开发模式：查看控制台）', 'success');
    // 开发模式下验证码固定为 123456
    document.getElementById('reg-code').value = '123456';
  } catch (e) {
    showToast(e.message, 'error');
  }
}

async function handleLogin() {
  const phone = document.getElementById('login-phone').value;
  const password = document.getElementById('login-password').value;
  if (!phone || !password) {
    showToast('请填写手机号和密码', 'error');
    return;
  }
  try {
    await api.login(phone, password);
    showToast('登录成功', 'success');
    navigateTo('main');
  } catch (e) {
    showToast(e.message, 'error');
  }
}

async function handleRegister() {
  const phone = document.getElementById('reg-phone').value;
  const code = document.getElementById('reg-code').value;
  const password = document.getElementById('reg-password').value;
  const nickname = document.getElementById('reg-nickname').value;
  const trackId = parseInt(document.getElementById('reg-track').value);

  if (!/^1[3-9]\d{9}$/.test(phone)) { showToast('手机号格式错误', 'error'); return; }
  if (!code) { showToast('请输入验证码', 'error'); return; }
  if (password.length < 6 || password.length > 18) { showToast('密码长度6-18位', 'error'); return; }
  if (!/(?=.*[a-zA-Z])(?=.*\d)/.test(password)) { showToast('密码需包含字母和数字', 'error'); return; }
  if (nickname.length < 2 || nickname.length > 10) { showToast('昵称长度2-10位', 'error'); return; }
  if (!trackId) { showToast('请选择赛道', 'error'); return; }

  try {
    await api.register({ phone, code, password, nickname, trackId });
    showToast('注册成功！', 'success');
    navigateTo('main');
  } catch (e) {
    showToast(e.message, 'error');
  }
}

async function handleLogout() {
  api.logout();
  navigateTo('splash');
}

// ═══════════════════════════════════════════════════════
// Home - Timer
// ═══════════════════════════════════════════════════════

let timerState = {
  isRunning: false,
  isPaused: false,
  startTime: null,
  elapsed: 0,
  pausedElapsed: 0,
  subjectId: null,
  subjectName: null,
  interval: null,
};

function refreshHome() {
  updateTimerDisplay();
  loadTodayGoal();
  const user = api.currentUser;
  if (user) {
    document.getElementById('header-greeting').textContent = '你好，' + user.nickname;
  }
  const now = new Date();
  const weekdays = ['日', '一', '二', '三', '四', '五', '六'];
  document.getElementById('header-date').textContent =
    `${now.getFullYear()}年${now.getMonth()+1}月${now.getDate()}日 星期${weekdays[now.getDay()]}`;
}

async function startTimer() {
  // 获取科目列表
  let subjects = [];
  try {
    const resp = await api.getSubjects();
    subjects = resp.data || [];
  } catch (e) { /* ignore */ }

  // 选择科目
  if (subjects.length > 0) {
    const defaultSubj = subjects.find(s => s.isDefault);
    showSubjectPicker(subjects, (selected) => {
      _doStart(selected?.id, selected?.name);
    });
  } else {
    _doStart(null, null);
  }
}

function _doStart(subjectId, subjectName) {
  closeModal();
  timerState = {
    isRunning: true,
    isPaused: false,
    startTime: Date.now(),
    elapsed: 0,
    pausedElapsed: 0,
    subjectId: subjectId,
    subjectName: subjectName,
    interval: setInterval(updateTimerDisplay, 500),
  };

  updateTimerUI();
  showToast('开始学习！' + (subjectName ? ' 科目：' + subjectName : ''), 'success');
}

function pauseTimer() {
  if (!timerState.isRunning || timerState.isPaused) return;
  timerState.isPaused = true;
  timerState.pausedElapsed = Date.now() - timerState.startTime;
  clearInterval(timerState.interval);
  updateTimerUI();
}

function resumeTimer() {
  if (!timerState.isPaused) return;
  timerState.isPaused = false;
  timerState.startTime = Date.now() - timerState.pausedElapsed;
  timerState.interval = setInterval(updateTimerDisplay, 500);
  updateTimerUI();
}

async function stopTimer() {
  if (!timerState.isRunning) return;
  const durationMs = timerState.isPaused
    ? timerState.pausedElapsed
    : Date.now() - timerState.startTime;
  const durationSeconds = Math.round(durationMs / 1000);

  if (durationSeconds < 1) {
    showToast('学习时长太短，未记录', 'error');
    resetTimer();
    return;
  }

  clearInterval(timerState.interval);

  // 备注输入
  const note = await promptAsync('添加学习备注（可选）', '如：复习了Java基础...');
  if (note === null) { // cancelled
    // still save
  }

  const now = new Date();
  const startedAt = new Date(now.getTime() - durationMs);

  try {
    const payload = {
      startedAt: startedAt.toISOString(),
      endedAt: now.toISOString(),
      durationSeconds,
    };
    if (timerState.subjectId) payload.subjectId = timerState.subjectId;
    if (note && note.trim()) payload.note = note.trim();

    await api.saveRecord(payload);
    showToast(`学习完成！共记录 ${formatDuration(durationSeconds)}`, 'success');
  } catch (e) {
    showToast('保存失败: ' + e.message, 'error');
  }

  resetTimer();
  refreshHome();
}

function resetTimer() {
  clearInterval(timerState.interval);
  timerState = {
    isRunning: false, isPaused: false,
    startTime: null, elapsed: 0, pausedElapsed: 0,
    subjectId: null, subjectName: null, interval: null,
  };
  updateTimerUI();
  updateTimerDisplay();
}

function updateTimerDisplay() {
  const display = document.getElementById('timer-display');
  if (!display) return;

  let totalMs = 0;
  if (timerState.isRunning && !timerState.isPaused) {
    totalMs = Date.now() - timerState.startTime;
  } else if (timerState.isPaused) {
    totalMs = timerState.pausedElapsed;
  }

  const totalSec = Math.floor(totalMs / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  display.textContent = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function updateTimerUI() {
  const subjectEl = document.getElementById('timer-subject');
  const statusEl = document.getElementById('timer-status');
  const btnStart = document.getElementById('btn-start');
  const runningControls = document.getElementById('timer-running-controls');
  const btnPause = document.getElementById('btn-pause');

  if (timerState.subjectName) {
    subjectEl.style.display = 'inline-block';
    subjectEl.textContent = timerState.subjectName;
  } else {
    subjectEl.style.display = 'none';
  }

  if (timerState.isRunning) {
    btnStart.style.display = 'none';
    runningControls.style.display = 'block';
    if (timerState.isPaused) {
      statusEl.textContent = '已暂停';
      btnPause.innerHTML = '<span class="material-icons">play_arrow</span> 继续';
    } else {
      statusEl.textContent = '专注学习中...';
      btnPause.innerHTML = '<span class="material-icons">pause</span> 暂停';
    }
  } else {
    btnStart.style.display = 'block';
    runningControls.style.display = 'none';
    statusEl.textContent = '点击开始，开启学习';
  }
}

function showSubjectPicker(subjects, callback) {
  let html = '<h3 style="margin-bottom:12px">选择学习科目</h3>';
  subjects.forEach(s => {
    html += `<div class="subject-item" onclick="selectSubject(${s.id}, '${s.name}', arguments[0])" style="cursor:pointer">
      <div class="subject-icon"><span class="material-icons">menu_book</span></div>
      <div class="subject-name">${s.name}</div>
      ${s.isDefault ? '<span class="material-icons subject-default">star</span>' : ''}
    </div>`;
  });
  html += `<div class="subject-item" onclick="selectSubject(null, null, arguments[0])" style="cursor:pointer;color:var(--text-secondary)">
    <div class="subject-icon"><span class="material-icons">block</span></div>
    <div class="subject-name">不选择科目</div>
  </div>`;

  window._subjectCallback = callback;
  showModal(html);
}

function selectSubject(id, name, event) {
  if (event) event.stopPropagation();
  if (window._subjectCallback) {
    window._subjectCallback(id ? { id, name } : null);
  }
  closeModal();
  if (timerState.isRunning) {
    timerState.subjectId = id;
    timerState.subjectName = name;
    updateTimerUI();
  }
}

function promptAsync(title, placeholder) {
  return new Promise((resolve) => {
    const html = `
      <h3 style="margin-bottom:12px">${title}</h3>
      <input type="text" id="prompt-input" placeholder="${placeholder}" maxlength="200" style="width:100%;padding:12px;border:1.5px solid var(--border);border-radius:12px;font-size:15px;margin-bottom:12px">
      <div style="display:flex;gap:8px">
        <button class="btn btn-outline" onclick="resolvePrompt(null)" style="flex:1">跳过</button>
        <button class="btn btn-primary" onclick="resolvePrompt(document.getElementById('prompt-input').value)" style="flex:1">保存</button>
      </div>`;
    window._promptResolve = resolve;
    showModal(html);
  });
}

function resolvePrompt(value) {
  closeModal();
  if (window._promptResolve) {
    window._promptResolve(value);
    window._promptResolve = null;
  }
}

// ═══════════════════════════════════════════════════════
// Today Goal
// ═══════════════════════════════════════════════════════

async function loadTodayGoal() {
  const user = api.currentUser;
  if (!user || !user.dailyGoalSec) {
    document.getElementById('goal-card').style.display = 'none';
    return;
  }

  try {
    const statsResp = await api.getStats();
    const todaySec = statsResp.data.todaySec || 0;
    const goal = user.dailyGoalSec;
    const progress = Math.min(todaySec / goal, 1);
    const remaining = Math.max(goal - todaySec, 0);

    document.getElementById('goal-card').style.display = 'block';
    document.getElementById('goal-pct').textContent = Math.round(progress * 100) + '%';
    document.getElementById('goal-progress').style.width = (progress * 100) + '%';
    document.getElementById('goal-remaining').textContent =
      remaining > 0 ? `距离目标还有 ${formatDuration(remaining)}` : '今日目标已完成！';
  } catch (e) { /* ignore */ }
}

// ═══════════════════════════════════════════════════════
// Records
// ═══════════════════════════════════════════════════════

let recordFilter = 'today';

async function setRecordFilter(filter, btn) {
  recordFilter = filter;
  document.querySelectorAll('#tab-records .chip').forEach(c => c.classList.remove('active'));
  if (btn) btn.classList.add('active');
  await loadRecords();
}

async function loadRecords() {
  let startDate, endDate;
  const now = new Date();
  const fmt = d => d.toISOString().split('T')[0];

  switch (recordFilter) {
    case 'today': startDate = fmt(now); break;
    case 'yesterday':
      const y = new Date(now); y.setDate(y.getDate() - 1);
      startDate = fmt(y); endDate = fmt(y); break;
    case '7days':
      const w = new Date(now); w.setDate(w.getDate() - 6);
      startDate = fmt(w); break;
    case '30days':
      const m = new Date(now); m.setDate(m.getDate() - 29);
      startDate = fmt(m); break;
  }

  try {
    const [recordsResp, statsResp] = await Promise.all([
      api.getRecords({ startDate, endDate, limit: 50 }),
      api.getStats(),
    ]);

    // Update stats
    const stats = statsResp.data;
    document.getElementById('stat-today').textContent = formatDuration(stats.todaySec);
    document.getElementById('stat-week').textContent = formatDuration(stats.weekSec);
    document.getElementById('stat-month').textContent = formatDuration(stats.monthSec);
    document.getElementById('stat-total').textContent = formatDuration(stats.totalSec);

    // Update records list
    const records = recordsResp.data.list || [];
    const listEl = document.getElementById('records-list');
    if (records.length === 0) {
      listEl.innerHTML = '<div class="empty-state">暂无学习记录</div>';
    } else {
      listEl.innerHTML = records.map(r => {
        const subjName = r.subjectName || r.subject_name || null;
        const durationSec = r.durationSeconds || r.duration_seconds || 0;
        const started = r.startedAt || r.started_at || '';
        const ended = r.endedAt || r.ended_at || '';
        const note = r.note || '';
        const synced = r.isSynced !== undefined ? r.isSynced : (r.is_synced !== undefined ? r.is_synced : true);
        return `
        <div class="record-item">
          <div class="record-icon">${(subjName || '学')[0]}</div>
          <div class="record-info">
            <div class="record-subject">${subjName || '自由学习'}</div>
            <div class="record-time">${formatDateTime(started)} — ${formatTime(ended)}</div>
            ${note ? `<div class="record-note">${note}</div>` : ''}
          </div>
          <div class="record-duration">${formatDuration(durationSec)}</div>
          <span class="material-icons record-sync ${synced ? 'synced' : 'not-synced'}">${synced ? 'cloud_done' : 'cloud_off'}</span>
        </div>
      `}).join('');
    }
  } catch (e) {
    console.error('加载记录失败:', e);
  }
}

// ═══════════════════════════════════════════════════════
// Leaderboard
// ═══════════════════════════════════════════════════════

let lbPeriod = 'day';

async function setPeriod(period, btn) {
  lbPeriod = period;
  document.querySelectorAll('.period-tab').forEach(t => t.classList.remove('active'));
  if (btn) btn.classList.add('active');
  await loadLeaderboard();
}

async function loadLeaderboard() {
  try {
    const resp = await api.getLeaderboard(lbPeriod, null, 50);
    const data = resp.data;

    // Track name
    document.getElementById('my-rank-track').textContent = data.track?.name || '';

    // My rank
    const myRank = data.myRank;
    const rankPos = document.getElementById('my-rank-position');
    const rankGap = document.getElementById('my-rank-gap');
    if (myRank && myRank.rank) {
      rankPos.textContent = `当前排名 第${myRank.rank}名`;
      rankGap.innerHTML = myRank.aboveDiffSec && myRank.aboveDiffSec > 0
        ? `<div style="font-size:11px;opacity:0.8">距上一名</div><div>还差${Math.ceil(myRank.aboveDiffSec / 60)}分钟</div>`
        : '';
    } else {
      rankPos.textContent = '暂未上榜';
      rankGap.innerHTML = '';
    }

    // Ad
    const adBanner = document.getElementById('ad-banner');
    if (data.advertisement) {
      adBanner.style.display = 'flex';
      adBanner.innerHTML = `
        <span class="ad-badge">赞助</span>
        <span style="font-size:12px;color:#666;margin-right:6px">${data.advertisement.advertiserName}</span>
        <span style="font-weight:600">${data.advertisement.materialName}</span>`;
    } else {
      adBanner.style.display = 'none';
    }

    // Entries
    const entries = data.entries || [];
    const userId = api.currentUser?.id;

    // Top 3
    const top3 = entries.filter(e => e.rank <= 3);
    const top3El = document.getElementById('top3-section');
    if (top3.length > 0) {
      // Sort 2-1-3
      const order = { 1: 1, 2: 0, 3: 2 };
      top3.sort((a, b) => (order[a.rank] || 3) - (order[b.rank] || 3));

      top3El.innerHTML = top3.map(e => {
        const medalClass = e.rank === 1 ? 'medal-gold' : e.rank === 2 ? 'medal-silver' : 'medal-bronze';
        const medalIcon = e.rank === 1 ? 'emoji_events' : 'military_tech';
        return `
          <div class="top3-item">
            ${e.userId === userId ? '<div style="font-size:10px;color:var(--primary);margin-bottom:4px">我</div>' : ''}
            <div class="top3-medal ${medalClass}">
              <span class="material-icons">${medalIcon}</span>
            </div>
            <div class="top3-name">${e.nickname}</div>
            <div class="top3-duration">${formatDuration(e.durationSec)}</div>
          </div>`;
      }).join('');
    } else {
      top3El.innerHTML = '';
    }

    // Rank list (4+)
    const restEntries = entries.filter(e => e.rank > 3);
    const rankList = document.getElementById('rank-list');
    rankList.innerHTML = restEntries.map(e => {
      let rankDisplay = '';
      if (e.rank <= 9) {
        rankDisplay = `<span class="rank-number">${e.rank}</span>`;
      } else if (e.rank <= 50) {
        rankDisplay = `<span class="rank-badge" style="background:#1976D2">50</span>`;
      } else if (e.rank <= 100) {
        rankDisplay = `<span class="rank-badge" style="background:#4CAF50">100</span>`;
      } else {
        rankDisplay = `<span class="rank-number">${e.rank}</span>`;
      }

      return `
        <div class="rank-item ${e.userId === userId ? 'is-me' : ''}" onclick="viewUserDetail(${e.userId}, '${e.nickname}', '${formatDuration(e.durationSec)}')">
          ${rankDisplay}
          <div class="rank-avatar">${e.nickname[0]}</div>
          <div class="rank-info">
            <div class="rank-name">${e.nickname}${e.userId === userId ? ' <span style="color:var(--primary);font-size:12px">(我)</span>' : ''}</div>
          </div>
          <div class="rank-duration">${formatDuration(e.durationSec)}</div>
        </div>`;
    }).join('');

  } catch (e) {
    console.error('加载排行榜失败:', e);
  }
}

async function viewUserDetail(userId, nickname, duration) {
  try {
    const resp = await api.getUserDetail(userId);
    const data = resp.data;
    let html = `<h3 style="margin-bottom:8px">${data.nickname || nickname}</h3>
      <p style="color:var(--text-secondary);margin-bottom:16px">学习时长: ${duration}</p>`;

    if (data.details && data.details.length > 0) {
      html += '<h4 style="margin-bottom:8px">近7天学习明细</h4>';
      data.details.slice(0, 7).forEach(d => {
        const h = Math.floor(d.totalSec / 3600);
        const m = Math.floor((d.totalSec % 3600) / 60);
        html += `<div style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--border)">
          <span>${d.date} - ${d.subjectName || '学习'}</span>
          <span style="font-weight:600;color:var(--primary)">${h > 0 ? h + 'h' + m + 'm' : m + 'm'}</span>
        </div>`;
      });
    } else {
      html += '<p style="color:var(--text-secondary)">该用户隐藏了学习详情</p>';
    }

    showModal(html);
  } catch (e) {
    showToast('加载失败', 'error');
  }
}

// ═══════════════════════════════════════════════════════
// Profile
// ═══════════════════════════════════════════════════════

async function loadProfile() {
  try {
    const [userResp, statsResp] = await Promise.all([
      api.getMe(),
      api.getUserStats(),
    ]);

    const user = userResp.data;
    const stats = statsResp.data;

    // 头像
    const avEl = document.getElementById('profile-avatar');
    if (avEl) {
      const avUrl = user.avatarUrl || user.avatar_url;
      avEl.innerHTML = avUrl
        ? '<img src="' + avUrl + '" style="width:100%;height:100%;object-fit:cover" onerror="this.innerHTML=\'<span class=material-icons style=font-size:36px>person</span>\'">'
        : '<span class="material-icons" style="font-size:36px">person</span>';
    }
    document.getElementById('profile-name').textContent = user.nickname;
    const genderLabel = { male: '♂ 男', female: '♀ 女', secret: '保密' };
    const genderEl = document.getElementById('profile-gender');
    if (genderEl) genderEl.textContent = genderLabel[user.gender] || '';
    const ageEl = document.getElementById('profile-age');
    if (ageEl && user.birthday) {
      const age = Math.floor((Date.now() - new Date(user.birthday).getTime()) / 31557600000);
      ageEl.textContent = age > 0 ? age + '岁' : '';
    } else if (ageEl) {
      ageEl.textContent = '';
    }
    document.getElementById('profile-track').textContent =
      (user.track_id ? '赛道: ' + (user.track?.name || '') : '未设置赛道');

    // Badges
    const badgesEl = document.getElementById('profile-badges');
    if (user.badges && user.badges.length > 0) {
      badgesEl.innerHTML = user.badges.map(b => {
        if (b === 'discipline_master') return '<span class="badge badge-gold"><span class="material-icons" style="font-size:14px">star</span> 自律达人</span>';
        if (b === 'persistence_star') return '<span class="badge badge-star"><span class="material-icons" style="font-size:14px">emoji_events</span> 坚持之星</span>';
        return '';
      }).join('');
    } else {
      badgesEl.innerHTML = '';
    }

    document.getElementById('pstat-total').textContent = formatDuration(stats.totalSec);
    document.getElementById('pstat-days').textContent = (stats.studyDays || 0) + '天';
    document.getElementById('pstat-avg').textContent = formatDuration(stats.avgDailySec || 0);
    document.getElementById('pstat-streak').textContent = (stats.maxStreakDays || 0) + '天';

    // Update stored user
    api.currentUser = user;

    // 管理员入口
    const adminEntry = document.getElementById('admin-entry');
    if (adminEntry) {
      adminEntry.style.display = user.is_admin ? 'flex' : 'none';
    }
  } catch (e) {
    console.error('加载个人中心失败:', e);
  }
}

let _pendingAvatarUrl = null; // 上传后的头像URL

function showEditProfile() {
  const user = api.currentUser;
  if (!user) return;
  const uid = 'edit-' + Date.now();
  const g = user.gender || 'secret';
  const bday = user.birthday || '';
  _pendingAvatarUrl = null;
  const html = `
    <h3 style="margin-bottom:16px">编辑个人信息</h3>
    <div class="form-group" style="text-align:center">
      <div style="width:72px;height:72px;border-radius:50%;background:var(--primary);margin:0 auto 8px;display:flex;align-items:center;justify-content:center;font-size:32px;color:#fff;overflow:hidden;cursor:pointer" id="${uid}-avatar-preview" onclick="document.getElementById('${uid}-file').click()">
        ${_avatarImg(user.avatarUrl || user.avatar_url)}
      </div>
      <input type="file" id="${uid}-file" accept="image/*" style="display:none" onchange="_handleAvatarPick('${uid}', this)">
      <div id="${uid}-avatar-status" style="font-size:12px;color:var(--text-secondary);margin-top:4px">
        点击头像选择本地图片上传
      </div>
    </div>
    <div class="form-group">
      <label>昵称（2-10位）</label>
      <input type="text" id="${uid}-nick" value="${escapeHtml(user.nickname || '')}" maxlength="10">
    </div>
    <div class="form-group">
      <label>性别</label>
      <select id="${uid}-gender">
        <option value="secret" ${g==='secret'?'selected':''}>保密</option>
        <option value="male" ${g==='male'?'selected':''}>男</option>
        <option value="female" ${g==='female'?'selected':''}>女</option>
      </select>
    </div>
    <div class="form-group">
      <label>生日</label>
      <input type="date" id="${uid}-birthday" value="${bday}" max="${new Date().toISOString().split('T')[0]}">
    </div>
    <div class="form-group">
      <label>赛道</label>
      <select id="${uid}-track">
        <option value="">加载中...</option>
      </select>
    </div>
    <button class="btn btn-primary btn-block" id="${uid}-btn">保存</button>`;
  showModal(html);

  // 加载赛道
  setTimeout(async () => {
    try {
      const resp = await api.getTracks();
      const sel = document.getElementById(uid + '-track');
      if (!sel) return;
      sel.innerHTML = '';
      const cats = {};
      (resp.data || []).forEach(t => {
        if (!cats[t.category]) cats[t.category] = [];
        cats[t.category].push(t);
      });
      for (const [cat, items] of Object.entries(cats)) {
        const og = document.createElement('optgroup');
        og.label = cat;
        items.forEach(item => {
          const opt = document.createElement('option');
          opt.value = item.id;
          opt.textContent = item.name;
          if (item.id === user.track_id || item.id === user.trackId) opt.selected = true;
          og.appendChild(opt);
        });
        sel.appendChild(og);
      }
    } catch {}
  }, 150);

  // 保存
  setTimeout(() => {
    const btn = document.getElementById(uid + '-btn');
    if (!btn) return;
    btn.onclick = async () => {
      const nickEl = document.getElementById(uid + '-nick');
      if (!nickEl) return;
      const nickname = nickEl.value.trim();
      if (nickname.length < 2 || nickname.length > 10) {
        showToast('昵称长度2-10位', 'error'); return;
      }
      btn.disabled = true; btn.textContent = '保存中...';
      try {
        const data = { nickname };
        const trackEl = document.getElementById(uid + '-track');
        const avatarEl = document.getElementById(uid + '-avatar');
        const genderEl = document.getElementById(uid + '-gender');
        const bdayEl = document.getElementById(uid + '-birthday');
        if (trackEl && trackEl.value) data.trackId = parseInt(trackEl.value);
        if (_pendingAvatarUrl) data.avatarUrl = _pendingAvatarUrl;
        if (genderEl) data.gender = genderEl.value;
        if (bdayEl && bdayEl.value) data.birthday = bdayEl.value;
        else data.birthday = null;
        await api.updateProfile(data);
        closeModal();
        showToast('保存成功', 'success');
        loadProfile();
      } catch (e) {
        showToast(e.message, 'error');
        btn.disabled = false; btn.textContent = '保存';
      }
    };
  }, 200);
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function _avatarImg(url) {
  if (!url) return '<span class="material-icons" style="font-size:36px">person</span>';
  return '<img src="' + url + '" style="width:100%;height:100%;object-fit:cover" onerror="this.innerHTML=\'<span class=material-icons style=font-size:36px>person</span>\'">';
}

async function _handleAvatarPick(uid, fileInput) {
  const file = fileInput.files[0];
  if (!file) return;
  var statusEl = document.getElementById(uid + '-avatar-status');
  if (statusEl) statusEl.textContent = '压缩中...';

  try {
    // Canvas 压缩
    const compressed = await _compressImage(file, 400, 400, 0.75);

    // 本地预览（使用压缩后的图片）
    var preview = document.getElementById(uid + '-avatar-preview');
    if (preview) {
      var reader = new FileReader();
      reader.onload = function(e) {
        preview.innerHTML = '<img src="' + e.target.result + '" style="width:100%;height:100%;object-fit:cover">';
      };
      reader.readAsDataURL(compressed);
    }

    // 上传压缩后的文件
    var originalSize = (file.size / 1024).toFixed(0);
    var compressedSize = (compressed.size / 1024).toFixed(0);
    if (statusEl) statusEl.textContent = '上传中(' + compressedSize + 'KB)...';
    const resp = await api.uploadAvatar(compressed);
    _pendingAvatarUrl = resp.data.avatarUrl;
    if (statusEl) {
      var note = originalSize !== compressedSize ? ' (已从' + originalSize + 'KB压缩至' + compressedSize + 'KB)' : '';
      statusEl.textContent = '头像已上传' + note;
      statusEl.style.color = 'var(--success)';
    }
  } catch (e) {
    if (statusEl) { statusEl.textContent = '上传失败: ' + e.message; statusEl.style.color = 'var(--danger)'; }
  }
}

function _compressImage(file, maxW, maxH, quality) {
  return new Promise(function(resolve, reject) {
    var img = new Image();
    img.onload = function() {
      var w = img.width, h = img.height;
      if (w > maxW || h > maxH) {
        var ratio = Math.min(maxW / w, maxH / h);
        w = Math.round(w * ratio);
        h = Math.round(h * ratio);
      }
      var canvas = document.createElement('canvas');
      canvas.width = w;
      canvas.height = h;
      var ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0, w, h);
      canvas.toBlob(function(blob) {
        if (blob) {
          var compressed = new File([blob], file.name.replace(/\.[^.]+$/, '.jpg'), { type: 'image/jpeg' });
          resolve(compressed);
        } else {
          // toBlob fallback: 不支持时直接返回原文件
          resolve(file);
        }
      }, 'image/jpeg', quality);
    };
    img.onerror = function() { resolve(file); };
    img.src = URL.createObjectURL(file);
  });
}

function showPrivacySettings() {
  const user = api.currentUser || {};
  const showDetails = user.show_details !== undefined ? user.show_details : user.showDetails;
  const showRank = user.show_rank !== undefined ? user.show_rank : user.showRank;
  const uid = 'privacy-' + Date.now();
  showModal(`
    <h3 style="margin-bottom:16px">隐私设置</h3>
    <div class="settings-item" style="cursor:default">
      <span>显示学习详情</span>
      <label class="switch"><input type="checkbox" id="${uid}-details" ${showDetails !== false ? 'checked' : ''}><span class="slider"></span></label>
    </div>
    <div class="settings-item" style="cursor:default">
      <span>在排行榜中显示排名</span>
      <label class="switch"><input type="checkbox" id="${uid}-rank" ${showRank !== false ? 'checked' : ''}><span class="slider"></span></label>
    </div>`);
  setTimeout(() => {
    var dEl = document.getElementById(uid + '-details');
    var rEl = document.getElementById(uid + '-rank');
    if (dEl) dEl.onchange = () => updatePrivacy('showDetails', dEl.checked);
    if (rEl) rEl.onchange = () => updatePrivacy('showRank', rEl.checked);
  }, 100);
}

async function updatePrivacy(key, value) {
  try {
    await api.updateProfile({ [key]: value });
    // 同步更新本地 currentUser
    if (api.currentUser) {
      var snakeKey = key.replace(/([A-Z])/g, '_$1').toLowerCase();
      api.currentUser[snakeKey] = value;
      api.currentUser[key] = value;
    }
    showToast('设置已更新', 'success');
  } catch (e) {
    showToast(e.message, 'error');
  }
}

async function updateSetting(key, value) {
  try {
    const data = {};
    // Convert checkbox boolean to proper type
    if (key === 'showAds') data.showAds = value === true || value === 'true';
    else if (key === 'antiSwitchSec') data.antiSwitchSec = parseInt(value);
    else data[key] = value;
    await api.updateProfile(data);
    showToast('设置已更新', 'success');
  } catch (e) {
    showToast(e.message, 'error');
  }
}

async function setDailyGoal() {
  const user = api.currentUser || {};
  const html = `
    <h3 style="margin-bottom:16px">每日学习目标</h3>
    <div class="form-group">
      <label>每日目标（小时）</label>
      <input type="number" id="goal-hours" value="${Math.floor((user.dailyGoalSec || 0) / 3600)}" min="0" max="24" step="0.5">
      <span style="font-size:12px;color:var(--text-secondary)">当前: ${formatDuration(user.dailyGoalSec || 0)}/天</span>
    </div>
    <button class="btn btn-primary btn-block" onclick="saveDailyGoal()">保存</button>`;
  showModal(html);
}

async function saveDailyGoal() {
  const hours = parseFloat(document.getElementById('goal-hours').value);
  if (isNaN(hours) || hours < 0) { showToast('请输入有效时长', 'error'); return; }
  const sec = Math.round(hours * 3600);
  try {
    await api.updateProfile({ dailyGoalSec: sec });
    closeModal();
    showToast('目标已更新', 'success');
    loadProfile();
    loadTodayGoal();
  } catch (e) {
    showToast(e.message, 'error');
  }
}

function showAbout() {
  showModal(`
    <div style="text-align:center">
      <span class="material-icons" style="font-size:48px;color:var(--primary)">school</span>
      <h2 style="margin:8px 0">学榜记</h2>
      <p style="color:var(--text-secondary)">版本 1.0.0</p>
      <p style="color:var(--text-secondary);margin-top:8px">学习时长记录与同赛道排行榜</p>
      <p style="color:var(--text-secondary);margin-top:4px;font-size:12px">© 2026 学榜记</p>
    </div>`);
}

// ═══════════════════════════════════════════════════════
// Subjects Management
// ═══════════════════════════════════════════════════════

async function loadSubjects() {
  try {
    const resp = await api.getSubjects();
    const subjects = resp.data || [];
    const list = document.getElementById('subjects-list');

    if (subjects.length === 0) {
      list.innerHTML = '<div class="empty-state">暂无科目，点击右上角添加</div>';
    } else {
      list.innerHTML = subjects.map(s => `
        <div class="subject-item">
          <div class="subject-icon"><span class="material-icons">${s.icon || 'menu_book'}</span></div>
          <div class="subject-name">${s.name}</div>
          ${s.isDefault ? '<span class="material-icons subject-default" title="默认科目">star</span>' : ''}
          <button class="btn-icon" onclick="setDefaultSubject(${s.id})" title="设为默认"><span class="material-icons">${s.isDefault ? 'star' : 'star_outline'}</span></button>
          <button class="btn-icon" onclick="deleteSubjectConfirm(${s.id}, '${s.name}')" title="删除"><span class="material-icons" style="color:var(--danger)">delete</span></button>
        </div>
      `).join('');
    }
  } catch (e) {
    console.error('加载科目失败:', e);
  }
}

function showAddSubject() {
  showModal(`
    <h3 style="margin-bottom:16px">添加科目</h3>
    <div class="form-group">
      <label>科目名称</label>
      <input type="text" id="new-subject-name" placeholder="如：Java编程" maxlength="20">
    </div>
    <button class="btn btn-primary btn-block" onclick="addSubject()">添加</button>`);
}

async function addSubject() {
  const name = document.getElementById('new-subject-name').value.trim();
  if (!name) { showToast('请输入科目名称', 'error'); return; }
  try {
    await api.createSubject(name);
    closeModal();
    showToast('科目已添加', 'success');
    loadSubjects();
  } catch (e) {
    showToast(e.message, 'error');
  }
}

async function setDefaultSubject(id) {
  try {
    await api.updateSubject(id, { isDefault: true });
    showToast('已设为默认科目', 'success');
    loadSubjects();
  } catch (e) {
    showToast(e.message, 'error');
  }
}

async function deleteSubjectConfirm(id, name) {
  showModal(`
    <h3 style="margin-bottom:12px">删除科目</h3>
    <p style="color:var(--text-secondary);margin-bottom:16px">确定要删除"${name}"吗？该科目下的学习记录不会丢失。</p>
    <div style="display:flex;gap:8px">
      <button class="btn btn-outline" onclick="closeModal()" style="flex:1">取消</button>
      <button class="btn btn-danger" onclick="deleteSubject(${id})" style="flex:1">删除</button>
    </div>`);
}

async function deleteSubject(id) {
  try {
    await api.deleteSubject(id);
    closeModal();
    showToast('科目已删除', 'success');
    loadSubjects();
  } catch (e) {
    showToast(e.message, 'error');
  }
}

// ═══════════════════════════════════════════════════════
// Notifications
// ═══════════════════════════════════════════════════════

async function loadNotifications() {
  try {
    const resp = await api.getNotifications(30);
    const list = resp.data.list || [];
    const el = document.getElementById('notifications-list');

    if (list.length === 0) {
      el.innerHTML = '<div class="empty-state">暂无消息</div>';
    } else {
      el.innerHTML = list.map(n => `
        <div class="notif-item ${n.isRead ? 'read' : 'unread'}" onclick="markNotifRead(${n.id})">
          <div class="notif-title">${n.isRead ? '' : '● '}${n.title}</div>
          <div class="notif-content">${n.content}</div>
          <div class="notif-time">${formatDateTime(n.createdAt)}</div>
        </div>
      `).join('');
    }
  } catch (e) {
    console.error('加载通知失败:', e);
  }
}

async function markNotifRead(id) {
  try {
    await api.markRead(id);
    loadNotifications();
  } catch (e) { /* ignore */ }
}

// ═══════════════════════════════════════════════════════
// Dark Mode
// ═══════════════════════════════════════════════════════

function toggleDarkMode() {
  const isDark = document.getElementById('dark-mode-toggle').checked;
  document.documentElement.setAttribute('data-theme', isDark ? 'dark' : '');
}

// ═══════════════════════════════════════════════════════
// Utils
// ═══════════════════════════════════════════════════════

function formatDuration(sec) {
  if (!sec || sec === 0) return '0m';
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  if (h > 0) return h + 'h' + m + 'm';
  return m + 'm';
}

function formatDateTime(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  return `${d.getMonth()+1}月${d.getDate()}日 ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
}

function formatTime(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
}

// ═══════════════════════════════════════════════════════
// Admin
// ═══════════════════════════════════════════════════════

async function loadAdminAds() {
  try {
    const resp = await api.getAdminAds();
    const ads = resp.data || [];
    const el = document.getElementById('admin-ads-list');
    if (ads.length === 0) {
      el.innerHTML = '<div class="empty-state">暂无广告</div>';
    } else {
      el.innerHTML = ads.map(a => `
        <div class="ad-admin-item" style="background:var(--card-bg);border-radius:12px;padding:14px;margin-bottom:10px;box-shadow:var(--shadow)">
          <div style="display:flex;justify-content:space-between;align-items:start">
            <div>
              <strong>${a.advertiser_name}</strong>
              <span class="ad-badge" style="margin-left:8px">${a.period_type === 'month' ? '月榜' : '总榜'}</span>
              ${a.is_active ? '<span style="color:var(--success);margin-left:4px;font-size:12px">● 已上线</span>' : '<span style="color:var(--text-secondary);margin-left:4px;font-size:12px">○ 待审核</span>'}
              <div style="font-size:13px;margin-top:4px">${a.material_name}</div>
              ${a.months ? '<div style="font-size:11px;color:var(--text-secondary)">月份: ' + a.months + '</div>' : ''}
            </div>
            <div style="display:flex;gap:4px">
              <button class="btn btn-sm btn-outline" onclick="toggleAdActive(${a.id}, ${!a.is_active})">${a.is_active ? '下线' : '审核通过'}</button>
              <button class="btn btn-sm btn-danger-outline" onclick="deleteAdminAd(${a.id})">删除</button>
            </div>
          </div>
        </div>
      `).join('');
    }
  } catch (e) {
    console.error('加载广告列表失败:', e);
  }
}

function showAddAd() {
  const uid = 'ad-' + Date.now();
  showModal(`
    <h3 style="margin-bottom:16px">添加广告</h3>
    <div class="form-group">
      <label>广告商名称</label>
      <input type="text" id="${uid}-name" placeholder="如：XX教育机构" maxlength="100">
    </div>
    <div class="form-group">
      <label>实物名称</label>
      <input type="text" id="${uid}-material" placeholder="如：编程书籍一套" maxlength="200">
    </div>
    <div class="form-group">
      <label>实物图片URL（可选）</label>
      <input type="text" id="${uid}-image" placeholder="https://...">
    </div>
    <div class="form-group">
      <label>广告类型</label>
      <select id="${uid}-type">
        <option value="month">月榜</option>
        <option value="total">总榜</option>
      </select>
    </div>
    <div class="form-group">
      <label>赞助月份（月榜时填写，JSON数组，如 ["2026-05","2026-06"]）</label>
      <input type="text" id="${uid}-months" placeholder='["2026-05","2026-06"]'>
    </div>
    <div class="form-group">
      <label>
        <input type="checkbox" id="${uid}-active" checked> 审核通过（直接上线）
      </label>
    </div>
    <button class="btn btn-primary btn-block" id="${uid}-btn">添加</button>
  `);
  setTimeout(() => {
    document.getElementById(uid + '-btn').onclick = async () => {
      const btn = document.getElementById(uid + '-btn');
      btn.disabled = true; btn.textContent = '添加中...';
      try {
        await api.createAd({
          advertiserName: document.getElementById(uid + '-name').value.trim(),
          materialName: document.getElementById(uid + '-material').value.trim(),
          materialImage: document.getElementById(uid + '-image').value.trim() || undefined,
          periodType: document.getElementById(uid + '-type').value,
          months: document.getElementById(uid + '-months').value.trim() || undefined,
          isActive: document.getElementById(uid + '-active').checked,
        });
        closeModal();
        showToast('广告已添加', 'success');
        loadAdminAds();
      } catch (e) {
        showToast(e.message, 'error');
        btn.disabled = false; btn.textContent = '添加';
      }
    };
  }, 150);
}

async function toggleAdActive(id, active) {
  try {
    await api.updateAd(id, { isActive: active });
    showToast(active ? '广告已上线' : '广告已下线', 'success');
    loadAdminAds();
  } catch (e) { showToast(e.message, 'error'); }
}

async function deleteAdminAd(id) {
  showModal(`
    <h3>确认删除</h3>
    <p style="margin:12px 0;color:var(--text-secondary)">确定要删除此广告吗？此操作不可撤销。</p>
    <div style="display:flex;gap:8px">
      <button class="btn btn-outline" onclick="closeModal()" style="flex:1">取消</button>
      <button class="btn btn-danger" id="confirm-delete-btn" style="flex:1">确认删除</button>
    </div>
  `);
  setTimeout(() => {
    const btn = document.getElementById('confirm-delete-btn');
    if (btn) btn.onclick = async () => {
      try {
        await api.deleteAd(id);
        closeModal();
        showToast('广告已删除', 'success');
        loadAdminAds();
      } catch (e) { showToast(e.message, 'error'); }
    };
  }, 100);
}

// ═══════════════════════════════════════════════════════
// Init
// ═══════════════════════════════════════════════════════

(function init() {
  // Check if already logged in
  if (accessToken) {
    api.getMe().then(() => {
      navigateTo('main');
    }).catch(() => {
      api.logout();
      navigateTo('splash');
    });
  } else {
    navigateTo('splash');
  }
})();
