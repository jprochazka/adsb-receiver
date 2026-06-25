export interface BlogPostLike {
  tags?: unknown;
  category?: string | null;
}

export interface CatalogEntry {
  name: string;
  count: number;
}

export function getPostTags(post: BlogPostLike | null | undefined): string[] {
  if (!Array.isArray(post?.tags)) return [];

  return post.tags
    .map((tag) => String(tag ?? '').trim())
    .filter((tag) => !!tag);
}

export function deduplicateTags(tags: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];

  for (const rawTag of tags) {
    const tag = rawTag.trim();
    if (!tag) continue;

    const key = tag.toLowerCase();
    if (seen.has(key)) continue;

    seen.add(key);
    result.push(tag);
  }

  return result;
}

export function buildTagCatalog(posts: BlogPostLike[]): CatalogEntry[] {
  const counts = new Map<string, CatalogEntry>();

  for (const post of posts) {
    for (const rawTag of getPostTags(post)) {
      const tag = rawTag.trim();
      if (!tag) continue;

      const key = tag.toLowerCase();
      const existing = counts.get(key);
      if (existing) {
        existing.count += 1;
        continue;
      }

      counts.set(key, { name: tag, count: 1 });
    }
  }

  return Array.from(counts.values()).sort((a, b) => a.name.localeCompare(b.name));
}

export function resolveBlogCategory(category: string, customCategory: string): string {
  if (category === '__new__') {
    return customCategory.trim() || 'Uncategorized';
  }

  return category || 'Uncategorized';
}

export function buildCategoryCatalog(posts: BlogPostLike[]): CatalogEntry[] {
  const counts = new Map<string, CatalogEntry>();

  counts.set('uncategorized', { name: 'Uncategorized', count: 0 });

  for (const post of posts) {
    const category = (post.category ?? '').trim() || 'Uncategorized';
    const key = category.toLowerCase();
    const existing = counts.get(key);

    if (existing) {
      existing.count += 1;
      continue;
    }

    counts.set(key, { name: category, count: 1 });
  }

  return Array.from(counts.values()).sort((a, b) => a.name.localeCompare(b.name));
}
