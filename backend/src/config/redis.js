/**
 * 内存 Redis 模拟实现（用于本地开发和测试）
 * 实现与 node-redis 兼容的 API
 */
require('dotenv').config();

class MemoryRedis {
  constructor() {
    this._data = new Map();        // key → value
    this._sortedSets = new Map();  // key → Map(member → score)
    this._expires = new Map();     // key → expiryTime
  }

  _checkExpiry(key) {
    const expiry = this._expires.get(key);
    if (expiry && Date.now() > expiry) {
      this._data.delete(key);
      this._sortedSets.delete(key);
      this._expires.delete(key);
      return true;
    }
    return false;
  }

  // ── 基础操作 ──────────────────────────────────────
  async set(key, value) { this._data.set(key, String(value)); return 'OK'; }
  async setEx(key, ttl, value) {
    this._data.set(key, String(value));
    this._expires.set(key, Date.now() + ttl * 1000);
    return 'OK';
  }
  async get(key) { this._checkExpiry(key); return this._data.get(key) || null; }
  async del(key) { this._data.delete(key); this._sortedSets.delete(key); this._expires.delete(key); return 1; }

  // ── Sorted Set ────────────────────────────────────
  _getSet(key) {
    this._checkExpiry(key);
    if (!this._sortedSets.has(key)) this._sortedSets.set(key, new Map());
    return this._sortedSets.get(key);
  }

  async zAdd(key, score, member) {
    this._getSet(key).set(String(member), parseFloat(score));
    return 1;
  }

  async zIncrBy(key, increment, member) {
    const set = this._getSet(key);
    const mem = String(member);
    const current = set.get(mem) || 0;
    const newScore = current + parseFloat(increment);
    set.set(mem, newScore);
    return newScore;
  }

  async zScore(key, member) {
    return this._getSet(key).get(String(member)) || null;
  }

  async zRevRank(key, member) {
    const set = this._getSet(key);
    const score = set.get(String(member));
    if (score === undefined) return null;
    const sorted = [...set.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
    return sorted.findIndex(([m]) => m === String(member));
  }

  async zRange(key, start, stop, opts = {}) {
    const set = this._getSet(key);
    let entries = [...set.entries()];
    entries.sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
    if (!opts.REV) entries.sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]));

    if (start < 0) start = Math.max(0, entries.length + start);
    if (stop < 0) stop = entries.length + stop;
    const slice = entries.slice(start, stop + 1);

    if (opts.REV) {
      // zRangeWithScores 风格返回 [{value, score}, ...]
    }
    return slice.map(([value, score]) => ({ value, score: String(score) }));
  }

  async zRangeWithScores(key, start, stop, opts = {}) {
    return this.zRange(key, start, stop, { REV: true, ...opts });
  }

  // ── TTL/过期 ─────────────────────────────────────
  async expire(key, ttl) {
    if (this._data.has(key) || this._sortedSets.has(key)) {
      this._expires.set(key, Date.now() + ttl * 1000);
      return 1;
    }
    return 0;
  }

  // ── 事务（简单实现） ─────────────────────────────
  multi() {
    const queue = [];
    const self = this;
    return {
      zIncrBy(key, inc, mem) { queue.push(() => self.zIncrBy(key, inc, mem)); return this; },
      expire(key, ttl) { queue.push(() => self.expire(key, ttl)); return this; },
      async exec() {
        const results = [];
        for (const fn of queue) results.push(await fn());
        return results;
      },
    };
  }

  async connect() { return true; }
  on() {}
}

let redisClient = null;

async function connectRedis() {
  redisClient = new MemoryRedis();
  console.log('✅ 内存缓存初始化成功（开发模式）');
}

function getRedis() {
  if (!redisClient) throw new Error('缓存未初始化');
  return redisClient;
}

module.exports = { connectRedis, getRedis };
