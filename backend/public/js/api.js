/**
 * 学榜记 API 客户端（Web 前端）
 */

const API_BASE = '/api/v1';
let accessToken = localStorage.getItem('access_token');
let refreshToken = localStorage.getItem('refresh_token');
let currentUser = null;

const api = {
  async request(method, path, data = null, params = null) {
    const headers = { 'Content-Type': 'application/json' };
    if (accessToken) headers['Authorization'] = `Bearer ${accessToken}`;

    const url = new URL(API_BASE + path, window.location.origin);
    if (params) {
      Object.keys(params).forEach(k => {
        if (params[k] !== null && params[k] !== undefined) url.searchParams.set(k, params[k]);
      });
    }

    const opts = { method, headers };
    if (data && method !== 'GET') opts.body = JSON.stringify(data);

    let resp = await fetch(url.toString(), opts);

    // Token 过期，尝试刷新
    if (resp.status === 401 && refreshToken) {
      const refreshResp = await fetch(API_BASE + '/auth/refresh', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken }),
      });
      if (refreshResp.ok) {
        const refreshData = await refreshResp.json();
        accessToken = refreshData.data.accessToken;
        refreshToken = refreshData.data.refreshToken;
        localStorage.setItem('access_token', accessToken);
        localStorage.setItem('refresh_token', refreshToken);
        headers['Authorization'] = `Bearer ${accessToken}`;
        opts.headers = headers;
        resp = await fetch(url.toString(), opts);
      } else {
        // 刷新失败，清除登录态
        api.logout();
        throw new Error('登录已过期，请重新登录');
      }
    }

    const json = await resp.json();
    if (!resp.ok) {
      throw new Error(json.message || '请求失败');
    }
    return json;
  },

  get(path, params) { return this.request('GET', path, null, params); },
  post(path, data) { return this.request('POST', path, data); },
  patch(path, data) { return this.request('PATCH', path, data); },
  delete(path) { return this.request('DELETE', path); },

  // Auth
  async login(phone, password) {
    const resp = await this.post('/auth/login', { phone, password });
    accessToken = resp.data.accessToken;
    refreshToken = resp.data.refreshToken;
    currentUser = resp.data.user;
    localStorage.setItem('access_token', accessToken);
    localStorage.setItem('refresh_token', refreshToken);
    return resp;
  },

  async register(data) {
    const resp = await this.post('/auth/register', data);
    accessToken = resp.data.accessToken;
    refreshToken = resp.data.refreshToken;
    currentUser = resp.data.user;
    localStorage.setItem('access_token', accessToken);
    localStorage.setItem('refresh_token', refreshToken);
    return resp;
  },

  async sendSms(phone, purpose = 'register') {
    return this.post('/auth/sms', { phone, purpose });
  },

  logout() {
    accessToken = null;
    refreshToken = null;
    currentUser = null;
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
  },

  // Tracks
  async getTracks() { return this.get('/auth/tracks'); },

  // User
  async getMe() {
    const resp = await this.get('/users/me');
    currentUser = resp.data;
    return resp;
  },

  async updateProfile(data) {
    const updates = {};
    const keys = ['nickname', 'trackId', 'avatarUrl', 'gender', 'birthday',
      'dailyGoalSec', 'weeklyGoalSec', 'monthlyGoalSec',
      'antiSwitchSec', 'showAds', 'showDetails', 'showRank'];
    keys.forEach(k => {
      if (data[k] !== undefined) updates[k] = data[k];
    });
    return this.patch('/users/me', updates);
  },

  async getUserStats() { return this.get('/users/me/stats'); },

  // Subjects
  async getSubjects() { return this.get('/subjects'); },
  async createSubject(name, icon = 'book') { return this.post('/subjects', { name, icon }); },
  async updateSubject(id, data) { return this.patch(`/subjects/${id}`, data); },
  async deleteSubject(id) { return this.delete(`/subjects/${id}`); },

  // Records
  async saveRecord(data) { return this.post('/records', data); },
  async getRecords(params) { return this.get('/records', params); },
  async getStats() { return this.get('/records/stats'); },
  async getTrend(days = 7) { return this.get('/records/trend', { days }); },

  // Leaderboard
  async getLeaderboard(period = 'day', trackId = null, limit = 50) {
    return this.get('/leaderboard', { period, trackId, limit });
  },
  async getMyRanks() { return this.get('/leaderboard/my-rank'); },
  async getUserDetail(userId) { return this.get(`/leaderboard/user/${userId}`); },

  // Notifications
  async getNotifications(limit = 30) { return this.get('/notifications', { limit }); },
  async markRead(id) { return this.patch(`/notifications/${id}/read`); },
  async markAllRead() { return this.post('/notifications/read-all'); },
  async deleteNotification(id) { return this.delete(`/notifications/${id}`); },
  async clearNotifications() { return this.delete('/notifications'); },
  async getUnreadCount() { return this.get('/notifications/unread-count'); },

  async uploadAvatar(file) {
    const formData = new FormData();
    formData.append('avatar', file);
    const headers = {};
    if (accessToken) headers['Authorization'] = 'Bearer ' + accessToken;
    const resp = await fetch(API_BASE + '/users/me/avatar', { method: 'POST', headers, body: formData });
    const json = await resp.json();
    if (!resp.ok) throw new Error(json.message || '上传失败');
    return json;
  },

  // Admin
  async getAdminAds() { return this.get('/admin/ads'); },
  async createAd(data) { return this.post('/admin/ads', data); },
  async updateAd(id, data) { return this.patch(`/admin/ads/${id}`, data); },
  async deleteAd(id) { return this.delete(`/admin/ads/${id}`); },
  async getAdminUsers(limit, offset) { return this.get('/admin/users', { limit, offset }); },
  async setUserAdmin(userId, isAdmin) { return this.patch(`/admin/users/${userId}/admin`, { isAdmin }); },
};
