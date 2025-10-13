type CacheEntry<T> = {
  value: T;
  expiresAt: number;
  persistent: boolean;
};

export class MemoryCache {
  private store = new Map<string, CacheEntry<unknown>>();

  get<T>(key: string): T | null {
    const entry = this.store.get(key);
    if (!entry) {
      return null;
    }

    if (!entry.persistent && entry.expiresAt < Date.now()) {
      this.store.delete(key);
      return null;
    }

    return entry.value as T;
  }

  set<T>(key: string, value: T, ttlMs: number, persistent = false): void {
    const expiresAt = persistent ? Number.POSITIVE_INFINITY : Date.now() + ttlMs;
    this.store.set(key, { value, expiresAt, persistent });
  }

  invalidate(key: string): void {
    this.store.delete(key);
  }

  invalidateWhere(predicate: (key: string) => boolean): void {
    for (const key of this.store.keys()) {
      if (predicate(key)) {
        this.store.delete(key);
      }
    }
  }

  clear(): void {
    this.store.clear();
  }
}

export const memoryCache = new MemoryCache();

