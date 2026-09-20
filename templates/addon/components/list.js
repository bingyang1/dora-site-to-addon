// components/list.js —— 分类列表（分页）
// 路由：$route('list', { cid: 6, name: '电影' })

// 统一的解析函数：放在文件顶部，search.js 也复制一份（或挂到 global）
function parseList($) {
  const items = []
  $('div.stui-vodlist__box').each((i, el) => {   // ★ 换成目标站点的选择器
    const $el = $(el)
    const title = clean($el.find('h4').text())
    const href = $el.find('h4 a').attr('href') || ''
    const styleAttr = $el.find('a.stui-vodlist__thumb').attr('style') || ''
    const m = styleAttr.match(/url\(['"]?(.*?)['"]?\)/)
    let image = m ? m[1] : $el.find('img').attr('data-original') || $el.find('img').attr('src')
    const label = clean($el.find('p').text())
    if (!title) return
    items.push({
      title: title,
      style: 'vod',
      image: absUrl(image),
      label: label,
      route: $route('detail', { url: absUrl(href), title: title })
    })
  })
  return items
}

module.exports = {
  type: 'list',
  searchRoute: $route('search'),
  translucent: true,
  allowBookmark: true,

  beforeCreate() {
    this.title = (this.args && this.args.name) || '列表'
  },

  async fetch({ args, page }) {
    const p = page || 1
    try {
      const url = `${base}/vod/${args.cid}-${p}.html`
      console.log('[list] GET', url)
      const resp = await $http.get(url, { headers: HEADERS, timeout: 15000 })
      const items = parseList(cheerio.load(resp.data))
      if (!items.length) {
        return { nextPage: null, items: [{ style: 'simple', title: '没有更多内容了' }] }
      }
      return { nextPage: p + 1, items: items }
    } catch (e) {
      console.error('[list] error', e)
      this.error = '加载失败：' + e.message
      return { items: [] }
    }
  }
}
