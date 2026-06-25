import {
  buildCategoryCatalog,
  buildTagCatalog,
  deduplicateTags,
  getPostTags,
  resolveBlogCategory,
} from './admin-blog.helpers';

describe('admin blog helpers', () => {
  it('getPostTags should trim tags and remove blank values', () => {
    expect(getPostTags({ tags: [' news ', '', '  ', 'ML'] })).toEqual(['news', 'ML']);
    expect(getPostTags({ tags: 'news' })).toEqual([]);
    expect(getPostTags(null)).toEqual([]);
  });

  it('deduplicateTags should preserve first casing and ignore blank duplicates case-insensitively', () => {
    expect(deduplicateTags([' News ', 'news', 'Update', '', ' update '])).toEqual(['News', 'Update']);
  });

  it('buildTagCatalog should aggregate normalized tag counts alphabetically', () => {
    const posts = [
      { tags: ['News', ' ads-b '] },
      { tags: ['news', '', 'UAT'] },
      { tags: ['uat'] },
    ];

    expect(buildTagCatalog(posts)).toEqual([
      { name: 'ads-b', count: 1 },
      { name: 'News', count: 2 },
      { name: 'UAT', count: 2 },
    ]);
  });

  it('buildCategoryCatalog should seed Uncategorized and aggregate blank categories', () => {
    const posts = [
      { category: 'News' },
      { category: ' news ' },
      { category: '' },
      { category: null },
    ];

    expect(buildCategoryCatalog(posts)).toEqual([
      { name: 'News', count: 2 },
      { name: 'Uncategorized', count: 2 },
    ]);
  });

  it('resolveBlogCategory should use custom category only when selected and fall back to Uncategorized', () => {
    expect(resolveBlogCategory('__new__', ' Custom ')).toBe('Custom');
    expect(resolveBlogCategory('__new__', '   ')).toBe('Uncategorized');
    expect(resolveBlogCategory('News', 'Ignored')).toBe('News');
    expect(resolveBlogCategory('', '')).toBe('Uncategorized');
  });
});
