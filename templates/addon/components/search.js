// components/search.js —— 搜索
// 由两处进入：
//   1) 组件的 searchRoute: $route('search')  → 页面右上角搜索按钮
//   2) package.json contributes.search = "search" → App 全局搜索
// 关键词通过 args.keyword 传入。

function parseSearchList($) {
  const items = []
  $('div.stui-vodlist__box').each((i, el) => {   // ★ 换成目标站点的选择器
    const $el = $(el)
    const title = clean($el.find('h4').text())
    const href = $el.find('h4 a').attr('href') || ''
    const styleAttr = $el.find('a.stui-vodlist__thumb').attr('style') || ''
    const m = styleAttr.match(/url\(['"]?(.*?)['"]?\)/)
    let image = m ? m[1] : $el.find('img').attr('data-original') || $el.find('img').attr('src')
    if (!title) return
    items.push({
      title: title,
      style: 'vod',
      image: absUrl(image),
      label: clean($el.find('p').text()),
      route: $route('detail', { url: absUrl(href), title: title })
    })
  })
  return items
}

module.exports = {
  type: 'list',
  tabMode: 'fixed',

  async fetch({ args, page }) {
    const p = page || 1
    const kw = (args && args.keyword) || ''
    if (!kw) return { title: '搜索', items: [{ style: 'simple', title: '请输入关键词' }] }

    try {
      const url =
        `${base}/vodsearch/----------${p}---.html?wd=${encodeURIComponent(kw)}&submit=`
      console.log('[search] GET', url)
      const resp = await $http.get(url, { headers: HEADERS, timeout: 15000 })
      const items = parseSearchList(cheerio.load(resp.data))
      return {
        title: kw + ' 的搜索结果',
        nextPage: items.length ? p + 1 : null,
        items: items.length ? items : [{ style: 'simple', title: '没有找到相关内容' }]
      }
    } catch (e) {
      console.error('[search] error', e)
      this.error = '搜索失败：' + e.message
      return { items: [] }
    }
  }
}